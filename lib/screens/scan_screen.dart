import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../main.dart';
import '../models.dart';
import '../services/ai_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  /// Lets the diary open the scanner on a specific meal.
  static final preselect = ValueNotifier<Meal?>(null);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanItem {
  FoodItem base; // as returned by the AI (base grams)
  FoodItem current; // after the user edits grams
  bool keep = true;
  _ScanItem(this.base) : current = base;
}

class _ScanScreenState extends State<ScanScreen> {
  final picker = ImagePicker();
  final describe = TextEditingController();
  Meal meal = MealLabel.forHour(DateTime.now().hour);
  File? photo;
  bool busy = false;
  String? error;
  String resultName = '';
  String notes = '';
  List<_ScanItem> items = [];

  @override
  void initState() {
    super.initState();
    ScanScreen.preselect.addListener(_onPreselect);
  }

  void _onPreselect() {
    final m = ScanScreen.preselect.value;
    if (m != null && mounted) setState(() => meal = m);
  }

  @override
  void dispose() {
    ScanScreen.preselect.removeListener(_onPreselect);
    describe.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await picker.pickImage(source: src, maxWidth: 1600, imageQuality: 85);
      if (x == null) return;
      setState(() {
        photo = File(x.path);
        items = [];
        error = null;
      });
    } catch (e) {
      setState(() => error = 'Could not open the camera or gallery. Check app permissions.');
    }
  }

  Future<void> _analyse({required bool usePhoto}) async {
    final s = context.read<AppState>();
    final ai = context.read<AiService>();
    if (!usePhoto && describe.text.trim().isEmpty) {
      toast(context, 'Describe what you ate first.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      items = [];
    });
    try {
      final r = usePhoto
          ? await ai.analysePhoto(photo!, meal: meal, diet: s.profile!.diet)
          : await ai.analyseText(describe.text.trim(), meal: meal, diet: s.profile!.diet);
      setState(() {
        resultName = r.name;
        notes = r.notes;
        items = r.items.map(_ScanItem.new).toList();
        if (items.isEmpty) error = r.notes.isNotEmpty ? r.notes : 'No food found. Try another photo or describe the meal.';
      });
    } on AiException catch (e) {
      setState(() => error = e.message);
    } on TimeoutException {
      setState(() => error = 'The server at ${AiService.baseUrl} took too long to answer. Try again.');
    } on SocketException catch (e) {
      setState(() => error = "Can't reach the FitFuel server at ${AiService.baseUrl}. Is the backend running? (${e.message})");
    } catch (e) {
      setState(() => error = "Couldn't reach ${AiService.baseUrl}: $e");
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _addToDiary() async {
    final keep = items.where((i) => i.keep).map((i) {
      final f = i.current;
      f.portion = f.portion.isEmpty ? '${f.grams.round()} g' : '${f.portion} (${f.grams.round()} g)';
      return f;
    }).toList();
    if (keep.isEmpty) {
      toast(context, 'Tick at least one item.');
      return;
    }
    await context.read<AppState>().addFoods(meal, keep);
    if (!mounted) return;
    setState(() {
      items = [];
      photo = null;
      describe.clear();
    });
    toast(context, 'Added to ${meal.label}');
    Shell.goTo(context, 0);
  }

  @override
  Widget build(BuildContext context) {
    final selectedKcal = items.where((i) => i.keep).fold<double>(0, (a, i) => a + i.current.kcal);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Muted('AI calorie counter'),
        Text('Snap a meal', style: FF.display(26)),
        const SizedBox(height: 12),
        SegmentedButton<Meal>(
          segments: [for (final m in Meal.values) ButtonSegment(value: m, label: Text(m.label))],
          selected: {meal},
          showSelectedIcon: false,
          onSelectionChanged: (v) => setState(() => meal = v.first),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(aspectRatio: 4 / 3, child: Image.file(photo!, fit: BoxFit.cover)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                OutlinedButton(onPressed: busy ? null : () => _pick(ImageSource.camera), child: const Text('Retake')),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => _analyse(usePhoto: true),
                    icon: busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Icon(Icons.auto_awesome),
                    label: Text(busy ? 'Analysing…' : 'Analyse photo'),
                  ),
                ),
              ]),
            ] else ...[
              const SizedBox(height: 8),
              const Icon(Icons.photo_camera_outlined, size: 40, color: FF.accent),
              const SizedBox(height: 8),
              const Text('Take or upload a photo', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
              const Muted('Shoot from above with the whole plate in frame'),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        Panel(
          color: FF.sunk,
          outlined: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Or describe it', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: describe,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(hintText: '2 roti, 1 katori rajma, cucumber salad, 1 glass chaas'),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: busy ? null : () => _analyse(usePhoto: false),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Count calories'),
            ),
          ]),
        ),
        if (busy) ...[
          const SizedBox(height: 12),
          const Panel(
            child: Row(children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
              SizedBox(width: 12),
              Expanded(child: Muted('Identifying foods and portions. This can take up to a minute.')),
            ]),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Panel(color: FF.sunk, outlined: true, child: Text(error!, style: const TextStyle(color: FF.burn))),
        ],
        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Muted('Detected · ${meal.label}', size: 12),
                    Text(resultName.isEmpty ? 'Your meal' : resultName, style: FF.display(20)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fmt(selectedKcal), style: FF.display(28, color: FF.accent)),
                  const Muted('kcal selected', size: 12),
                ]),
              ]),
              for (final it in items) _row(it),
              if (notes.isNotEmpty) ...[const SizedBox(height: 10), Muted(notes)],
              const SizedBox(height: 6),
              const Muted('AI estimates can be off by 10–20%. Adjust grams if the portion looks wrong.', size: 12),
              const SizedBox(height: 12),
              FilledButton(onPressed: _addToDiary, child: Text('Add to ${meal.label}')),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _row(_ScanItem it) {
    final f = it.current;
    return Opacity(
      opacity: it.keep ? 1 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.only(top: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: FF.line))),
        child: Row(children: [
          Checkbox(value: it.keep, onChanged: (v) => setState(() => it.keep = v ?? false)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Muted(
                '${f.portion.isEmpty ? '' : '${f.portion} · '}${fmt(f.kcal)} kcal'
                '${f.confidence > 0 ? ' · ${(f.confidence * 100).round()}% sure' : ''}',
                size: 12,
              ),
            ]),
          ),
          SizedBox(
            width: 76,
            child: TextFormField(
              initialValue: '${f.grams.round()}',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(isDense: true, suffixText: 'g'),
              onChanged: (v) {
                final g = double.tryParse(v);
                if (g != null && g > 0) setState(() => it.current = it.base.scaledTo(g));
              },
            ),
          ),
        ]),
      ),
    );
  }
}
