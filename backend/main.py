"""FitFuel backend: AI meal recognition and coaching.

Run:
    pip install -r requirements.txt
    export GEMINI_API_KEY=...
    uvicorn main:app --host 0.0.0.0 --port 8000 --reload

The Flutter app calls this server, so the API key never ships inside the app.
"""

import json
import os
import re
import time
from functools import lru_cache

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import JSONResponse
from google import genai
from google.genai import types
from pydantic import BaseModel, Field

MODEL = os.environ.get("FITFUEL_MODEL", "gemini-3.5-flash")
# Tried in order when a model is overloaded (503) or rate limited (429).
FALLBACKS = ("gemini-3.5-flash-lite", "gemini-flash-lite-latest", "gemini-3-flash-preview", "gemini-3.7-flash", "gemini-3.8-flash")
MODELS = [MODEL] + [m for m in FALLBACKS if m != MODEL]
# Less hidden "thinking" = much faster replies. 3.5 supports "minimal"; the newer ones start at "low".
THINKING = {"gemini-3.5-flash": "minimal", "gemini-3.7-flash": "low", "gemini-3.8-flash": "low"}
MAX_PHOTO_BYTES = 8 * 1024 * 1024
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}

app = FastAPI(title="FitFuel API")

# The server is public, so cap how much any one address can spend of the AI quota.
LIMIT_PER_MINUTE = int(os.environ.get("RATE_PER_MINUTE", "12"))
LIMIT_PER_DAY = int(os.environ.get("RATE_PER_DAY", "150"))
_hits: dict[str, list[float]] = {}


@app.middleware("http")
async def rate_limit(request: Request, call_next):
    if request.url.path == "/health":
        return await call_next(request)
    # Behind a host's proxy the real address is the first X-Forwarded-For entry.
    fwd = request.headers.get("x-forwarded-for", "")
    ip = fwd.split(",")[0].strip() or (request.client.host if request.client else "?")
    now = time.time()
    recent = [t for t in _hits.get(ip, []) if now - t < 86400]
    if len(recent) >= LIMIT_PER_DAY or sum(1 for t in recent if now - t < 60) >= LIMIT_PER_MINUTE:
        return JSONResponse({"detail": "Too many requests. Please wait a bit and try again."}, status_code=429)
    recent.append(now)
    _hits[ip] = recent
    if len(_hits) > 5000:  # keep memory bounded
        for k in [k for k, v in _hits.items() if not v or now - v[-1] > 86400]:
            _hits.pop(k, None)
    return await call_next(request)


@lru_cache(maxsize=1)
def _client() -> genai.Client:
    return genai.Client()  # reads GEMINI_API_KEY (or GOOGLE_API_KEY)

SCAN_RULES = (
    "You estimate nutrition for an Indian calorie-tracking app. Identify each distinct food or drink. "
    "Estimate the portion in grams and in a household unit people in India use "
    "(katori, roti, piece, cup, glass, plate, tbsp, ladle). Use Indian Food Composition Tables (NIN) "
    "values where they apply and USDA values otherwise. Count visible or typical oil, ghee and butter. "
    "Round kcal to whole numbers and macros to one decimal. Reply with only JSON in this shape: "
    '{"meal_name":"Paneer thali","items":[{"name":"Paneer butter masala","portion":"1 katori","grams":180,'
    '"kcal":348,"protein_g":14.2,"carbs_g":12.0,"fat_g":27.5,"confidence":0.85}],"notes":"one short sentence"}. '
    'If there is no food, reply {"meal_name":"","items":[],"notes":"No food found"}.'
)


def _extract_json(text: str) -> dict:
    """Parse the model's reply, tolerating a code fence or a sentence around the JSON."""
    text = text.strip()
    fence = re.search(r"```(?:json)?\s*(.*?)```", text, re.S)
    if fence:
        text = fence.group(1)
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end == -1:
        raise HTTPException(502, "The AI reply had no JSON. Try again.")
    try:
        return json.loads(text[start : end + 1])
    except json.JSONDecodeError as e:
        raise HTTPException(502, "The AI reply was garbled. Try again.") from e


def _clean(data: dict) -> dict:
    items = []
    for it in data.get("items") or []:
        try:
            items.append(
                {
                    "name": str(it.get("name", "Food"))[:80],
                    "portion": str(it.get("portion", ""))[:40],
                    "grams": max(1.0, float(it.get("grams") or 100)),
                    "kcal": round(float(it.get("kcal") or 0)),
                    "protein_g": round(float(it.get("protein_g") or 0), 1),
                    "carbs_g": round(float(it.get("carbs_g") or 0), 1),
                    "fat_g": round(float(it.get("fat_g") or 0), 1),
                    "confidence": min(1.0, max(0.0, float(it.get("confidence") or 0))),
                }
            )
        except (TypeError, ValueError):
            continue
    return {"meal_name": str(data.get("meal_name", ""))[:60], "items": items, "notes": str(data.get("notes", ""))[:200]}


def _sniff(raw: bytes) -> str | None:
    """Detect the image type from its first bytes (phones often upload as octet-stream)."""
    if raw[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if raw[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if raw[:4] == b"RIFF" and raw[8:12] == b"WEBP":
        return "image/webp"
    if raw[:6] in (b"GIF87a", b"GIF89a"):
        return "image/gif"
    return None


def _ask(content: list, max_tokens: int = 4096, json_reply: bool = False) -> str:
    # Gemini counts its hidden "thinking" tokens against the output limit, so keep this generous.
    busy = None
    for attempt in range(2):  # two passes over the models; demand spikes clear quickly
        for model in MODELS:
            config = types.GenerateContentConfig(
                max_output_tokens=max_tokens,
                response_mime_type="application/json" if json_reply else None,
                thinking_config=(
                    types.ThinkingConfig(thinking_level=THINKING[model]) if model in THINKING else None
                ),
            )
            try:
                resp = _client().models.generate_content(model=model, contents=content, config=config)
                return resp.text or ""
            except Exception as e:  # network, auth, rate limits
                if getattr(e, "code", None) not in (429, 500, 503):
                    raise HTTPException(502, f"AI service error: {e.__class__.__name__}") from e
                busy = e
                print(f"[ai] {model} -> {getattr(e, 'code', '?')} {str(e)[:160]}", flush=True)
        time.sleep(3)
    raise HTTPException(503, "The AI is busy right now. Try again in a minute.") from busy


@app.get("/health")
def health():
    return {"ok": True, "model": MODEL}


@app.post("/analyze/photo")
async def analyze_photo(photo: UploadFile = File(...), meal: str = Form("lunch"), diet: str = Form("any")):
    raw = await photo.read()
    if len(raw) > MAX_PHOTO_BYTES:
        raise HTTPException(413, "Photo is too large. Keep it under 8 MB.")
    media_type = _sniff(raw) or photo.content_type
    if media_type not in ALLOWED_TYPES:
        raise HTTPException(415, "Send a JPG, PNG, WebP or GIF photo.")
    content = [
        types.Part.from_bytes(data=raw, mime_type=media_type),
        f"{SCAN_RULES} The user eats a {diet} diet. The image is a photo of their {meal}.",
    ]
    return _clean(_extract_json(_ask(content, json_reply=True)))


class TextMeal(BaseModel):
    text: str = Field(min_length=2, max_length=600)
    meal: str = "lunch"
    diet: str = "any"


@app.post("/analyze/text")
def analyze_text(body: TextMeal):
    prompt = (
        f'{SCAN_RULES} The user eats a {body.diet} diet. Instead of a photo, they described their '
        f'{body.meal} in words (any language): """{body.text}"""'
    )
    return _clean(_extract_json(_ask([prompt], json_reply=True)))


@app.post("/coach")
def coach(summary: dict):
    prompt = (
        "You are a friendly, practical fitness coach inside an Indian calorie app. Give 4 short, specific tips "
        "(one line each, start each with '• ') based on this person's data, then one line of encouragement. "
        "Suggest foods that fit their diet and are easy to get in India. Do not give medical advice.\n\n"
        + json.dumps(summary)[:20000]
    )
    return {"text": _ask([prompt], max_tokens=2048).strip()}
