// Web için file download helper
// Conditional import kullanarak web ve diğer platformlar için farklı implementasyon

export 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart';

