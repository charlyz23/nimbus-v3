import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart'
    show ThemeReader;

import '../codec/nimbus_codec.dart' as codec;
import '../data/offline_map_store.dart';
import '../data/town_pack.dart';
import 'theme.dart';

final _shortbreadTheme = ThemeReader().read({
  'version': 8,
  'name': 'Nimbus Offline',
  'sources': {
    'versatiles-shortbread': {'type': 'vector'},
  },
  'layers': [
    {
      'id': 'background',
      'type': 'background',
      'paint': {'background-color': '#f3f1ec'},
    },
    {
      'id': 'ocean',
      'type': 'fill',
      'source': 'versatiles-shortbread',
      'source-layer': 'ocean',
      'paint': {'fill-color': '#c9e5ed'},
    },
    {
      'id': 'water',
      'type': 'fill',
      'source': 'versatiles-shortbread',
      'source-layer': 'water_polygons',
      'paint': {'fill-color': '#b9dce7'},
    },
    {
      'id': 'buildings',
      'type': 'fill',
      'source': 'versatiles-shortbread',
      'source-layer': 'buildings',
      'paint': {'fill-color': '#dfd9cf'},
    },
    {
      'id': 'boundaries',
      'type': 'line',
      'source': 'versatiles-shortbread',
      'source-layer': 'boundaries',
      'paint': {'line-color': '#a49a8c', 'line-width': 1},
    },
    {
      'id': 'streets',
      'type': 'line',
      'source': 'versatiles-shortbread',
      'source-layer': 'streets',
      'paint': {'line-color': '#ffffff', 'line-width': 1.5},
    },
    {
      'id': 'place-labels',
      'type': 'symbol',
      'source': 'versatiles-shortbread',
      'source-layer': 'place_labels',
      'layout': {
        'text-field': ['get', 'name'],
        'text-size': 12,
      },
      'paint': {
        'text-color': '#33455b',
        'text-halo-color': '#ffffff',
        'text-halo-width': 1,
      },
    },
  ],
});

class StormMap extends StatefulWidget {
  const StormMap({
    super.key,
    required this.town,
    required this.tab,
    this.reply,
  });

  final Town town;
  final String tab;
  final codec.Reply? reply;

  @override
  State<StormMap> createState() => _StormMapState();
}

class _StormMapState extends State<StormMap> {
  final MapController _controller = MapController();
  final OfflineMapStore _mapStore = OfflineMapStore();

  static const locations = <String, LatLng>{
    '0412': LatLng(13.7565, 121.0583),
    '0517': LatLng(13.6218, 123.1948),
    '0837': LatLng(11.2440, 125.0030),
    '1374': LatLng(14.6507, 121.1029),
  };

  MbTiles? _mbtiles;
  MbTilesVectorTileProvider? _tileProvider;
  bool _checkingMap = true;
  bool _downloading = false;
  int _downloadedBytes = 0;
  int _totalBytes = OfflineMapStore.estimatedDownloadBytes;
  String? _mapError;

  LatLng get center =>
      locations[widget.town.code] ?? const LatLng(12.8797, 121.7740);

  @override
  void initState() {
    super.initState();
    _loadInstalledMap();
  }

  @override
  void dispose() {
    _mapStore.dispose();
    _mbtiles?.close();
    super.dispose();
  }

  Future<void> _loadInstalledMap() async {
    try {
      final mbtiles = await _mapStore.openInstalled();
      if (!mounted) {
        mbtiles?.close();
        return;
      }
      setState(() {
        _setMap(mbtiles);
        _checkingMap = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checkingMap = false;
        _mapError = 'Could not open the offline map: $error';
      });
    }
  }

  void _setMap(MbTiles? mbtiles) {
    _mbtiles?.close();
    _mbtiles = mbtiles;
    _tileProvider =
        mbtiles == null ? null : MbTilesVectorTileProvider(mbtiles: mbtiles);
  }

  Future<void> _confirmDownload() async {
    final download = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NimbusSizes.radius),
        ),
        title: const Text('Download Philippines offline map?'),
        content: const Text(
          'This one-time download is about 520 MB. Wi-Fi is strongly '
          'recommended. After it finishes, the map works without internet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (download == true && mounted) await _downloadMap();
  }

  Future<void> _downloadMap() async {
    setState(() {
      _downloading = true;
      _downloadedBytes = 0;
      _mapError = null;
    });

    try {
      final mbtiles = await _mapStore.download(
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _downloadedBytes = received;
            _totalBytes = total;
          });
        },
      );
      if (!mounted) {
        mbtiles.close();
        return;
      }
      setState(() {
        _setMap(mbtiles);
        _downloading = false;
      });
    } on OfflineMapDownloadCancelled {
      if (mounted) setState(() => _downloading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _mapError = 'Map download failed: $error';
      });
    }
  }

  void _cancelDownload() {
    _mapStore.cancelDownload();
  }

  @override
  void didUpdateWidget(covariant StormMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.town.code != widget.town.code) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.move(center, 12);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _shortbreadTheme;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 12,
        minZoom: 4,
        maxZoom: 18,
        backgroundColor: const Color(0xFFF3F1EC),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        if (_tileProvider case final tileProvider?)
          VectorTileLayer(
            theme: theme,
            tileProviders: TileProviders({
              'versatiles-shortbread': tileProvider,
            }),
            maximumZoom: 18,
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 150,
              height: 90,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(NimbusSizes.radius),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 6),
                      ],
                    ),
                    child: Text(
                      widget.town.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF234B83),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFF2467C5),
                    size: 30,
                  ),
                ],
              ),
            ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('© OpenStreetMap contributors · Geofabrik'),
          ],
        ),
        if (_tileProvider == null)
          Positioned(
            top: 170,
            left: 88,
            right: 12,
            child: _OfflineMapStatus(
              checking: _checkingMap,
              downloading: _downloading,
              downloadedBytes: _downloadedBytes,
              totalBytes: _totalBytes,
              error: _mapError,
              onDownload: _confirmDownload,
              onCancel: _cancelDownload,
            ),
          ),
      ],
    );
  }
}

class _OfflineMapStatus extends StatelessWidget {
  const _OfflineMapStatus({
    required this.checking,
    required this.downloading,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.error,
    required this.onDownload,
    required this.onCancel,
  });

  final bool checking;
  final bool downloading;
  final int downloadedBytes;
  final int totalBytes;
  final String? error;
  final VoidCallback onDownload;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final progress =
        totalBytes == 0 ? null : (downloadedBytes / totalBytes).clamp(0.0, 1.0);
    return Card(
      elevation: 5,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NimbusSizes.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Offline Philippines map',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            if (checking)
              const Text('Checking for an installed map...')
            else if (downloading) ...[
              const Text('Downloading map data. Keep Nimbus open.'),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 5),
              Text(
                '${_formatMegabytes(downloadedBytes)} of '
                '${_formatMegabytes(totalBytes)} downloaded',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
            ] else ...[
              if (error != null) ...[
                Text(
                  error!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 8),
              ] else
                const Text(
                  'A one-time download of about 520 MB is needed. Wi-Fi is '
                  'recommended; the map is then available offline.',
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download),
                  label: Text(error == null ? 'Download map' : 'Try again'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatMegabytes(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
