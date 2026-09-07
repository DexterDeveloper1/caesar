import 'package:caesar/features/reader/logic/reader_document.dart';
import 'package:caesar/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The imported documents, persisted between sessions.
class LibraryController extends Notifier<ReaderLibrary> {
  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  ReaderLibrary build() => _storage.readLibrary();

  void add(ReaderDocument document) {
    state = state.add(document);
    _storage.writeLibrary(state);
  }

  void remove(String id) {
    state = state.remove(id);
    _storage.writeLibrary(state);
  }

  /// Remembers where the reader stopped, so reopening resumes in place.
  void saveProgress(String id, int paragraph, {double? offset}) {
    state = state.withProgress(id, paragraph, offset: offset);
    _storage.writeLibrary(state);
  }
}

final libraryProvider = NotifierProvider<LibraryController, ReaderLibrary>(
  LibraryController.new,
);

/// Body text size, in logical pixels. Persisted because comfortable reading
/// size is personal and should not reset every session.
class ReaderFontSizeController extends Notifier<double> {
  StorageService get _storage => ref.read(storageServiceProvider);

  static const double min = 15;
  static const double max = 26;

  @override
  double build() => _storage.readReaderFontSize();

  void set(double size) {
    state = size.clamp(min, max);
    _storage.writeReaderFontSize(state);
  }
}

final readerFontSizeProvider =
    NotifierProvider<ReaderFontSizeController, double>(
      ReaderFontSizeController.new,
    );
