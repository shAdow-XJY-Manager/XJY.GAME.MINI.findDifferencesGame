import 'dart:js_interop';

@JS('managerArcade.read') external JSString? _read(JSString key);
@JS('managerArcade.write') external JSBoolean _write(JSString key,JSString value);
@JS('managerArcade.reduced') external JSBoolean _reduced();
@JS('managerArcade.watch') external void _watch(JSFunction callback);
@JS('managerArcade.unwatch') external void _unwatch();
@JS('managerArcade.tone') external void _tone(JSString kind);
@JS('managerArcade.asset') external JSString _asset(JSString path);
String? readValue(String key) { try { return _read(key.toJS)?.toDart; } catch (_) { return null; } }
bool writeValue(String key,String value) { try { return _write(key.toJS,value.toJS).toDart; } catch (_) { return false; } }
bool systemReducedMotion() { try { return _reduced().toDart; } catch (_) { return false; } }
void watchSuspension(void Function() callback) { try { _watch(callback.toJS); } catch (_) {} }
void unwatchSuspension() { try { _unwatch(); } catch (_) {} }
void playTone(String kind) { try { _tone(kind.toJS); } catch (_) {} }
String gameAsset(String path) { try { return _asset(path.toJS).toDart; } catch (_) { return Uri.base.resolve(path).toString(); } }
