import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../providers/auth_provider.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';

class NoteEditScreen extends StatefulWidget {
  final Note? note; // null => création d'une nouvelle note

  const NoteEditScreen({super.key, this.note});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late String _category;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _category = widget.note?.category ?? 'Autre';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  bool get _isEmpty => _titleController.text.trim().isEmpty && _contentController.text.trim().isEmpty;

  Future<void> _save() async {
    if (_isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Écrivez au moins un titre ou un contenu avant de sauvegarder.')),
      );
      return;
    }

    final notesProvider = context.read<NotesProvider>();
    final userId = context.read<AuthProvider>().currentUser!.id!;

    if (_isEditing) {
      await notesProvider.updateNote(
        widget.note!.copyWith(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _category,
        ),
      );
    } else {
      await notesProvider.addNote(
        Note(
          userId: userId,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _category,
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscard() async {
    final hasChanges = _titleController.text.trim() != (widget.note?.title ?? '') ||
        _contentController.text.trim() != (widget.note?.content ?? '') ||
        _category != (widget.note?.category ?? 'Autre');
    if (!hasChanges) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Annuler les modifications ?'),
        content: const Text('Les changements non enregistrés seront perdus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuer l\'édition')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _contentController.text.trim().isEmpty
        ? 0
        : _contentController.text.trim().split(RegExp(r'\s+')).length;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Modifier la note' : 'Nouvelle note'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (await _confirmDiscard() && mounted) Navigator.of(context).pop();
            },
          ),
          actions: [
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('ENREGISTRER', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _titleController,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: 'Titre de la note',
                          border: InputBorder.none,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const Divider(height: 24),
                      TextField(
                        controller: _contentController,
                        maxLines: null,
                        minLines: 8,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 16, height: 1.5),
                        decoration: const InputDecoration(
                          hintText: 'Écrivez votre note ici...',
                          border: InputBorder.none,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$wordCount mot${wordCount > 1 ? "s" : ""}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppColors.categoryColors.keys.map((cat) {
                    final selected = _category == cat;
                    final color = AppColors.categoryColors[cat]!;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (_) => setState(() => _category = cat),
                      selectedColor: color.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: selected ? color : Colors.grey.shade600,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(color: selected ? color : Colors.grey.shade300),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
