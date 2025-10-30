import '../../../core/error_handler.dart';

bool downloadCsvBytesImpl(List<int> bytes, {required String filename}) {
  AppLogger.warning('Intento de descarga CSV ($filename) en plataforma no compatible.');
  return false;
}