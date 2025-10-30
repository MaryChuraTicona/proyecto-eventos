import 'csv_downloader_stub.dart'
    if (dart.library.html) 'csv_downloader_web.dart';

/// Expone una única función para descargar archivos CSV.
bool downloadCsvBytes(List<int> bytes, {required String filename}) {
  return downloadCsvBytesImpl(bytes, filename: filename);
}