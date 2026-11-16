import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mbtiles/mbtiles.dart';
import 'package:path_provider/path_provider.dart';

class OfflineMapDownloadCancelled implements Exception {
  const OfflineMapDownloadCancelled();
}

class OfflineMapStore {
  OfflineMapStore({
    http.Client Function()? clientFactory,
    Future<Directory> Function()? directoryProvider,
  })  : _clientFactory = clientFactory ?? http.Client.new,
        _directoryProvider =
            directoryProvider ?? getApplicationSupportDirectory;

  static const mapUrl =
      'https://download.geofabrik.de/asia/philippines-shortbread-1.0.mbtiles';
  static const mapFileName = 'philippines-shortbread-1.0.mbtiles';
  static const estimatedDownloadBytes = 519278592;

  final http.Client Function() _clientFactory;
  final Future<Directory> Function() _directoryProvider;
  http.Client? _activeClient;
  bool _cancelRequested = false;

  Future<File> _mapFile() async {
    final directory = await _directoryProvider();
    return File('${directory.path}/$mapFileName');
  }

  Future<MbTiles?> openInstalled() async {
    final file = await _mapFile();
    final partialFile = File('${file.path}.download');
    if (await partialFile.exists()) await partialFile.delete();
    if (!await file.exists()) return null;
    return _openAndValidate(file);
  }

  Future<MbTiles> download({
    required void Function(int received, int total) onProgress,
  }) async {
    final destination = await _mapFile();
    final partialFile = File('${destination.path}.download');
    final client = _clientFactory();
    _activeClient = client;
    _cancelRequested = false;
    IOSink? sink;
    var receivedBytes = 0;

    try {
      if (await partialFile.exists()) await partialFile.delete();

      final uri = Uri.parse(mapUrl);
      final response = await client.send(http.Request('GET', uri));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Map server returned HTTP ${response.statusCode}.',
          uri: uri,
        );
      }

      final contentLength = response.contentLength;
      final totalBytes = contentLength != null && contentLength > 0
          ? contentLength
          : estimatedDownloadBytes;
      sink = partialFile.openWrite();
      var lastReportedBytes = 0;
      await for (final chunk in response.stream) {
        if (_cancelRequested) throw const OfflineMapDownloadCancelled();
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (receivedBytes - lastReportedBytes >= 1024 * 1024 ||
            receivedBytes == contentLength) {
          onProgress(receivedBytes, totalBytes);
          lastReportedBytes = receivedBytes;
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (_cancelRequested) throw const OfflineMapDownloadCancelled();
      if (contentLength != null &&
          contentLength > 0 &&
          receivedBytes != contentLength) {
        throw HttpException(
          'Incomplete map download: received $receivedBytes of '
          '$contentLength bytes.',
          uri: uri,
        );
      }

      final validation = _openAndValidate(partialFile);
      validation.close();
      if (await destination.exists()) await destination.delete();
      await partialFile.rename(destination.path);
      return _openAndValidate(destination);
    } catch (_) {
      if (sink != null) await sink.close();
      if (await partialFile.exists()) await partialFile.delete();
      if (_cancelRequested) throw const OfflineMapDownloadCancelled();
      rethrow;
    } finally {
      if (identical(_activeClient, client)) _activeClient = null;
      client.close();
    }
  }

  MbTiles _openAndValidate(File file) {
    final mbtiles = MbTiles(path: file.path, gzip: true);
    try {
      final format = mbtiles.getMetadata().format.toLowerCase();
      if (format != 'pbf') {
        throw FormatException('Expected PBF vector tiles, found "$format".');
      }
      return mbtiles;
    } catch (_) {
      mbtiles.close();
      rethrow;
    }
  }

  void cancelDownload() {
    _cancelRequested = true;
    _activeClient?.close();
  }

  void dispose() => cancelDownload();
}
