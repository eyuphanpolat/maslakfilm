import 'dart:typed_data';

/// Stub implementasyon (web dışı platformlar için)
Future<void> downloadFile(Uint8List bytes, String fileName) async {
  throw UnimplementedError('downloadFile sadece web platformunda kullanılabilir');
}

