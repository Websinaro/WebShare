import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/transfer_file.dart';

/// Holds the set of files the user has picked on the Send screen.
/// File picking itself goes through file_picker in the real build; the
/// controller only deals in the already-resolved TransferFile models so
/// the UI layer never touches platform file APIs directly.
class SendController extends Notifier<List<TransferFile>> {
  @override
  List<TransferFile> build() => [];

  void addFiles(List<TransferFile> files) {
    final existingIds = state.map((f) => f.id).toSet();
    state = [...state, ...files.where((f) => !existingIds.contains(f.id))];
  }

  void remove(String id) {
    state = state.where((f) => f.id != id).toList();
  }

  void clear() => state = [];

  int get totalBytes => state.fold(0, (sum, f) => sum + f.sizeBytes);
}

final sendControllerProvider = NotifierProvider<SendController, List<TransferFile>>(
  SendController.new,
);
