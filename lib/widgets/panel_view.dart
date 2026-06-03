import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../models/todo.dart';
import '../services/nlp_parser.dart';
import '../services/ollama_nlp_service.dart';
import '../services/theme_engine.dart';
import '../state/app_state.dart';
import 'todo_tile.dart';
import 'time_picker.dart';
import 'mood_selector.dart';
import 'dynamic_background.dart';
import 'weather_particle.dart';

class PanelView extends StatefulWidget {
  final AppState state;
  final VoidCallback onCollapse;
  final AuroraPalette palette;
  final String? weatherCode;
  final double weatherIntensity;

  const PanelView({
    super.key,
    required this.state,
    required this.onCollapse,
    required this.palette,
    this.weatherCode,
    this.weatherIntensity = 0.0,
  });

  @override
  State<PanelView> createState() => _PanelViewState();
}

class _PanelViewState extends State<PanelView> {
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();
  DateTime? _dueDate;
  String? _category;
  ParsedTask? _parsedPreview;
  final List<_Sparkle> _sparkles = [];
  late final Timer _sparkleTimer;

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(_onInputChanged);
    _sparkleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _sparkles.isNotEmpty) setState(() => _sparkles.clear());
    });
  }

  void _onInputChanged() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) {
      if (_parsedPreview != null) setState(() => _parsedPreview = null);
      return;
    }
    final parsed = NlpParser.parse(text);
    if (_parsedPreview?.dueDate != parsed.dueDate ||
        !_listsEqual(_parsedPreview?.tags ?? [], parsed.tags)) {
      setState(() => _parsedPreview = parsed.result);
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _sparkleTimer.cancel();
    super.dispose();
  }

  void _showTimePickerSheet() {
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: SingleChildScrollView(
          child: Container(
            width: 340,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Material(
              color: Colors.transparent,
              child: CompactTimePicker(
                initial: _dueDate,
                onPicked: (dt) {
                  setState(() => _dueDate = dt);
                  Navigator.of(ctx).pop();
                },
                onClear: () {
                  setState(() => _dueDate = null);
                  Navigator.of(ctx).pop();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
  void _addSparkle(Offset pos) {
    setState(() {
      _sparkles.add(_Sparkle(pos));
      if (_sparkles.length > 12) _sparkles.removeAt(0);
    });
  }

  Future<void> _addTodo() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();

    // Always run regex first (reliable date extraction)
    final regexResult = NlpParser.parse(text).result;
    // Try Ollama for smarter title + extra tags (merges below)
    ParsedTask? ollamaResult;
    try {
      ollamaResult = await OllamaNlpService.parse(text);
    } catch (_) {}

    // Merge: regex date first (deterministic, now handles "X之前"); Ollama fills gaps
    final due = _dueDate ?? regexResult.dueDate ?? ollamaResult?.dueDate;
    final title = ollamaResult?.title ?? regexResult.title;
    final tags = <String>{
      ...regexResult.tags,
      if (ollamaResult != null) ...ollamaResult.tags,
    }.toList();

    setState(() {
      _dueDate = null;
      _category = null;
    });
    widget.state.addTodo(title, dueDate: due, category: _category, tags: tags);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  void _editTodo(Todo todo) {
    final titleCtrl = TextEditingController(text: todo.title);
    DateTime? editDue = todo.dueDate;
    String? editCat = todo.category;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1e1b3a),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Task', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Task title',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF818cf8))),
                ),
              ),
              const SizedBox(height: 12),
              // Categories
              Row(children: ['personal', 'work', 'urgent'].map((c) {
                final sel = editCat == c;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setDialogState(() => editCat = sel ? null : c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: sel ? _catColor(c).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel ? _catColor(c).withOpacity(0.4) : Colors.white.withOpacity(0.08)),
                      ),
                      child: Text(_catLabel(c), style: TextStyle(fontSize: 11, color: sel ? _catColor(c) : Colors.white.withOpacity(0.4))),
                    ),
                  ),
                );
              }).toList()),
              const SizedBox(height: 10),
              // Due date
              GestureDetector(
                onTap: () async {
                  final picked = await showDialog<DateTime>(
                    context: ctx,
                    builder: (_) => Center(
                      child: SingleChildScrollView(
                        child: Container(
                          width: 340,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                          child: Material(
                            color: Colors.transparent,
                            child: CompactTimePicker(
                              initial: editDue,
                              onPicked: (dt) => Navigator.of(ctx).pop(dt),
                              onClear: () => Navigator.of(ctx).pop(null),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                  if (picked != null) setDialogState(() => editDue = picked);
                },
                child: Row(children: [
                  Icon(Icons.schedule, size: 14, color: editDue != null ? widget.palette.accent2 : Colors.white.withOpacity(0.3)),
                  const SizedBox(width: 6),
                  Text(
                    editDue != null
                        ? '${editDue!.month}/${editDue!.day} ${editDue!.hour}:${editDue!.minute.toString().padLeft(2, '0')}'
                        : 'Set due date',
                    style: TextStyle(fontSize: 12, color: editDue != null ? widget.palette.accent2 : Colors.white.withOpacity(0.3)),
                  ),
                  if (editDue != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setDialogState(() => editDue = null),
                      child: Icon(Icons.close, size: 12, color: Colors.white.withOpacity(0.2)),
                    ),
                  ],
                ]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.4))),
            ),
            TextButton(
              onPressed: () {
                widget.state.updateTodo(
                  todo.id,
                  title: titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : null,
                  dueDate: editDue,
                  category: editCat,
                );
                Navigator.of(ctx).pop();
              },
              child: const Text('Save', style: TextStyle(color: Color(0xFF818cf8))),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleTodo(String id) {
    widget.state.toggleTodo(id);
    // Only schedule auto-remove if becoming completed; re-check before deleting
    if (widget.state.todos.any((t) => t.id == id && t.completed)) {
      Future.delayed(const Duration(seconds: 2), () {
        if (widget.state.todos.any((t) => t.id == id && t.completed)) {
          widget.state.removeTodo(id);
        }
      });
    }
  }

  Future<void> _openClaude() async {
    try {
      await Process.start(
        'cmd', ['/c', 'start', 'claude'],
        mode: ProcessStartMode.detached,
      );
    } catch (_) {}
  }

  String _catLabel(String c) {
    switch (c) {
      case 'urgent': return 'Urgent';
      case 'work': return 'Work';
      case 'personal': return 'Personal';
      default: return c;
    }
  }

  Color _catColor(String c) {
    switch (c) {
      case 'urgent': return const Color(0xFFf87171);
      case 'work': return const Color(0xFF60a5fa);
      case 'personal': return const Color(0xFF34d399);
      default: return widget.palette.accent1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DynamicBackground(
        palette: widget.palette,
        showAurora: true,
        weatherCode: widget.weatherCode,
        weatherIntensity: widget.weatherIntensity,
        child: Stack(
          children: [
            Positioned.fill(
              child: WeatherParticle(
                weatherCode: widget.weatherCode,
                intensity: widget.weatherIntensity,
              ),
            ),
            Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xDD0f0c29), Color(0xDD302b63), Color(0xDD24243e)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF6366f1).withOpacity(0.15), blurRadius: 30, spreadRadius: -4),
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16),
                ],
              ),
              child: Stack(
        children: [
          Column(children: [
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6, left: 16, right: 14),
              child: Row(children: [
                const Spacer(),
                GestureDetector(
                  onTap: widget.onCollapse,
                  onPanStart: (_) => windowManager.startDragging(),
                  child: _MiniClock(palette: widget.palette),
                ),
                const Spacer(),
                // Peek button
                GestureDetector(
                  onTap: () {
                    // peek from panel: first collapse, then peek
                    widget.onCollapse();
                  },
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.chevron_right, size: 14,
                        color: Colors.white.withOpacity(0.3)),
                  ),
                ),
                const SizedBox(width: 6),
                // Quit button
                GestureDetector(
                  onTap: () {
                    windowManager.destroy();
                    Future.delayed(const Duration(milliseconds: 500), () => exit(0));
                  },
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.power_settings_new, size: 12,
                        color: Colors.white.withOpacity(0.3)),
                  ),
                ),
              ]),
            ),
            _buildInput(),
            if (_parsedPreview != null &&
                (_parsedPreview!.dueDate != null || _parsedPreview!.tags.isNotEmpty))
              _buildParsePreview(),
            const SizedBox(height: 6),
            _buildCategories(),
            const SizedBox(height: 6),
            MoodSelector(
              current: widget.state.mood,
              onChanged: widget.state.setMood,
            ),
            if (_dueDate != null) _dueBadge(),
            const SizedBox(height: 8),
            Expanded(child: ListenableBuilder(
              listenable: widget.state,
              builder: (context, _) {
                final active = widget.state.todos.where((t) => !t.completed).toList();
                final done = widget.state.todos.where((t) => t.completed).toList();
                if (active.isEmpty && done.isEmpty) return _emptyState();
                return ListView(
                  padding: const EdgeInsets.only(top: 2, bottom: 60),
                  children: [
                    ...active.map((t) => TodoTile(
                          todo: t, onToggle: () => _toggleTodo(t.id),
                          onDelete: () => widget.state.removeTodo(t.id),
                          onTap: () => _editTodo(t),
                        )),
                    if (done.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Completed', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11, letterSpacing: 1)),
                      ),
                      ...done.map((t) => TodoTile(
                            todo: t, onToggle: () => _toggleTodo(t.id),
                            onDelete: () => widget.state.removeTodo(t.id),
                            onTap: () => _editTodo(t),
                          )),
                    ],
                  ],
                );
              },
            )),
          ]),
          ..._sparkles.map((s) => Positioned(
                left: s.pos.dx - 6, top: s.pos.dy - 6,
                child: IgnorePointer(child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: 0.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (c, v, _) => Opacity(
                    opacity: v,
                    child: Transform.scale(scale: 2 - v, child: Icon(Icons.auto_awesome, size: 12, color: widget.palette.accent2)),
                  ),
                )),
              )),
          Positioned(
            right: 12, bottom: 12,
            child: GestureDetector(
              onTap: _openClaude,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [widget.palette.accent1, widget.palette.accent2]),
                  boxShadow: [BoxShadow(color: widget.palette.accent1.withOpacity(0.4), blurRadius: 12)],
                ),
                child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
              ),
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(Icons.add, size: 16, color: widget.palette.accent1),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: _inputCtrl, focusNode: _inputFocus,
            onSubmitted: (_) => _addTodo(),
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w300),
            decoration: InputDecoration(
              hintText: 'What needs doing?',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 14, fontWeight: FontWeight.w300),
              border: InputBorder.none, isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          )),
          GestureDetector(
            onTap: _showTimePickerSheet,
            child: Container(
              width: 32, height: 32,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: _dueDate != null ? widget.palette.accent2.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.schedule, size: 14, color: _dueDate != null ? widget.palette.accent2 : Colors.white.withOpacity(0.3)),
            ),
          ),
          GestureDetector(
            onTap: _addTodo,
            child: Container(
              width: 32, height: 32,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: widget.palette.accent1.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.arrow_forward_ios, size: 12, color: widget.palette.accent1),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCategories() {
    const cats = ['personal', 'work', 'urgent'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: cats.map((cat) {
        final sel = _category == cat;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => setState(() => _category = sel ? null : cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: sel ? _catColor(cat).withOpacity(0.2) : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sel ? _catColor(cat).withOpacity(0.4) : Colors.white.withOpacity(0.06)),
              ),
              child: Text(_catLabel(cat), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: sel ? _catColor(cat) : Colors.white.withOpacity(0.35))),
            ),
          ),
        );
      }).toList()),
    );
  }

  Widget _buildParsePreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 10, color: Colors.white.withOpacity(0.25)),
          const SizedBox(width: 6),
          if (_parsedPreview!.dueDate != null) ...[
            Icon(Icons.schedule, size: 10, color: widget.palette.accent2.withOpacity(0.6)),
            const SizedBox(width: 3),
            Text(
              '${_parsedPreview!.dueDate!.month}/${_parsedPreview!.dueDate!.day} '
              '${_parsedPreview!.dueDate!.hour}:${_parsedPreview!.dueDate!.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 10, color: widget.palette.accent2.withOpacity(0.6)),
            ),
            const SizedBox(width: 8),
          ],
          ..._parsedPreview!.tags.map((t) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('#$t', style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.3))),
            ),
          )),
        ],
      ),
    );
  }

  Widget _dueBadge() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        Icon(Icons.schedule, size: 12, color: widget.palette.accent2),
        const SizedBox(width: 4),
        Text('Due: ${_dueDate!.month}/${_dueDate!.day} ${_dueDate!.hour}:${_dueDate!.minute.toString().padLeft(2, '0')}',
          style: TextStyle(color: widget.palette.accent2, fontSize: 11, fontWeight: FontWeight.w300)),
      ]),
    );
  }

  Widget _emptyState() {
    final h = DateTime.now().hour;
    final g = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    return Center(
      child: GestureDetector(
        onTapDown: (d) => _addSparkle(d.localPosition),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome, size: 36, color: widget.palette.accent1),
            const SizedBox(height: 10),
            Text(g, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.w200, letterSpacing: 2)),
            const SizedBox(height: 4),
            Text('Your mind is clear', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12, fontWeight: FontWeight.w300, letterSpacing: 1)),
          ]),
        ),
      ),
    );
  }
}

class _MiniClock extends StatefulWidget {
  final AuroraPalette palette;
  const _MiniClock({required this.palette});
  @override
  State<_MiniClock> createState() => _MiniClockState();
}

class _MiniClockState extends State<_MiniClock> {
  late final Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [widget.palette.accent1, widget.palette.accent2],
      ).createShader(bounds),
      child: Text('$h:$m', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w200, color: Colors.white, letterSpacing: 3)),
    );
  }
}

class _Sparkle { final Offset pos; const _Sparkle(this.pos); }
