import 'dart:js_interop';
import 'dart:typed_data';

@JS('queueSha256')
external JSPromise<JSString> _queueSha256(JSUint8Array bytes);

Future<String> documentContentHash(Uint8List bytes) async {
  final hash = await _queueSha256(bytes.toJS).toDart;
  return hash.toDart;
}
