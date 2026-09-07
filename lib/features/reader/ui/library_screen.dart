import 'dart:io';

import 'package:caesar/app/router.dart';
import 'package:caesar/core/design.dart';
import 'package:caesar/core/widgets/juice.dart';
import 'package:caesar/features/reader/data/document_importer.dart';
import 'package:caesar/features/reader/logic/document_cleaner.dart';
import 'package:caesar/features/reader/logic/reader_document.dart';
import 'package:caesar/features/reader/state/library_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The reading list: import documents and pick one up where you left off.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _importing = false;

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: DocumentImporter.supportedExtensions.toList(),
      );
      final path = picked?.path;
      if (path == null) return;

      final document = await ref
          .read(documentImporterProvider)
          .import(File(path));
      if (!mounted) return;
      ref.read(libraryProvider.notifier).add(document);
    } on ImportException catch (error) {
      if (mounted) _explain(error.message);
    } catch (error) {
      if (mounted) _explain('Something went wrong importing that file.');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _explain(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Couldn't import"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final library = ref.watch(libraryProvider);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(onImport: _importing ? null : _import),
              if (_importing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: Insets.sm),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              Expanded(
                child: library.documents.isEmpty
                    ? _EmptyState(onImport: _importing ? null : _import)
                    : ListView.separated(
                        padding: const EdgeInsets.all(Insets.md),
                        itemCount: library.documents.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Insets.sm),
                        itemBuilder: (context, i) => _DocumentTile(
                          document: library.documents[i],
                          onOpen: () => context.push(
                            Routes.reader(library.documents[i].id),
                          ),
                          onDelete: () => ref
                              .read(libraryProvider.notifier)
                              .remove(library.documents[i].id),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  0,
                  Insets.md,
                  Insets.md,
                ),
                child: Text(
                  'PDF, EPUB and TXT. Text is cleaned and reflowed for '
                  'comfortable reading.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final ReaderDocument document;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _DocumentTile({
    required this.document,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final minutes = estimateReadingMinutes(document.paragraphs);
    final percent = (document.progress * 100).round();

    return Pressable(
      onPressed: onOpen,
      child: GlassCard(
        child: Row(
          children: [
            Icon(
              document.isFinished
                  ? Icons.task_alt_rounded
                  : Icons.menu_book_rounded,
              color: palette.textPrimary,
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${document.paragraphs.length} paragraphs · '
                    '~$minutes min · $percent% read',
                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: Insets.sm),
                  ClipRRect(
                    borderRadius: Radii.pill,
                    child: LinearProgressIndicator(
                      value: document.progress,
                      minHeight: 4,
                      backgroundColor: palette.surfaceBorder,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            Pressable(
              onPressed: onDelete,
              child: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: palette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onImport;

  const _EmptyState({required this.onImport});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    // Scrollable so the explanation and button survive short screens.
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_rounded,
              size: 56,
              color: palette.textMuted,
            ),
            const SizedBox(height: Insets.md),
            Text(
              'Nothing to read yet',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'Import a book or document. Caesar strips the page furniture, '
              'repairs broken line breaks and reflows the text so it is '
              'actually readable on a phone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, height: 1.5),
            ),
            const SizedBox(height: Insets.lg),
            Pressable(
              onPressed: onImport,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.md,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: Radii.card,
                ),
                child: const Text(
                  'Import a document',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback? onImport;

  const _TopBar({required this.onImport});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: [
          Pressable(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.surface,
                shape: BoxShape.circle,
                border: Border.all(color: palette.surfaceBorder),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: palette.textPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: Insets.md),
          Text(
            'Reading',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Pressable(
            onPressed: onImport,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.surface,
                shape: BoxShape.circle,
                border: Border.all(color: palette.surfaceBorder),
              ),
              child: Icon(
                Icons.add_rounded,
                color: palette.textPrimary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
