# Nimbus v3

 Nimbus app demo: a map-first Android app with a typhoon indicator, plus the SMS server view, keyword SMS for any phone, and the LGU console from v2.

| Path | What it is |
|---|---|
| `index.html` + `nimbus-codec.js` | Web demo. Simulated: sample data, no SMS is sent. |
| `nimbus-codec.js` | The NB1 SMS format with no DOM, so it reads like the ports below. |
| `codec/nimbus_codec.py` | Python backend codec. `python3 codec/nimbus_codec.py` checks it against the test vectors. |
| `codec/nimbus_codec.dart` | Dart codec for the Flutter app (also copied into `flutter_app/lib/codec/`). |
| `codec/NimbusCodec.kt` | Kotlin codec, for an Android-phone gateway or native code outside Flutter. |
| `codec/test_vectors.json` | Encoded replies made by the JS codec. Every port must produce the same strings. |
| `design/tokens.json`, `design/logo.svg` | Colors, touch sizes and the logo. |
| `flutter_app/` | Flutter app: map, tab rail, bottom sheet, SMS through `another_telephony`, saved updates in SQLite. |

## Run the Flutter app

The Android project is included in `flutter_app/`. To run it:

```bash
cd flutter_app
flutter pub get
flutter run
```

To build a release APK:

```bash
flutter build apk --release
```

The offline Philippines map is downloaded once from Geofabrik on first use
(about 520 MB) and stored on the device; it is not bundled in the APK. See
[`MAP_SETUP.txt`](MAP_SETUP.txt) for details and attribution.

## Security note

The NB1 `K` signature is a demo checksum, not authentication. Use HMAC-SHA256
with a server-held key before any real pilot.
- The Flutter map shows flood overlays only; the web demo also draws evacuation sites and roads.
