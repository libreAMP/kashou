import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../providers/audio_provider.dart';
import 'tray_service.dart';

const _root = 'org.mpris.MediaPlayer2';
const _player = 'org.mpris.MediaPlayer2.Player';
const _busName = 'org.mpris.MediaPlayer2.kashou';

// the shells only talk to one object so it answers both interfaces
class MprisObject extends DBusObject {
  MprisObject(this.audio, this.artUri)
      : super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  final AudioProvider audio;
  final Future<Uri?> Function(Track track) artUri;

  // one table feeds both the property replies and the introspection xml
  static const _playerTypes = {
    'PlaybackStatus': 's',
    'LoopStatus': 's',
    'Rate': 'd',
    'Shuffle': 'b',
    'Metadata': 'a{sv}',
    'Volume': 'd',
    'Position': 'x',
    'MinimumRate': 'd',
    'MaximumRate': 'd',
    'CanGoNext': 'b',
    'CanGoPrevious': 'b',
    'CanPlay': 'b',
    'CanPause': 'b',
    'CanSeek': 'b',
    'CanControl': 'b',
  };

  static const _rootTypes = {
    'CanQuit': 'b',
    'CanRaise': 'b',
    'HasTrackList': 'b',
    'Identity': 's',
    'DesktopEntry': 's',
    'SupportedUriSchemes': 'as',
    'SupportedMimeTypes': 'as',
  };

  static const _writable = {'LoopStatus', 'Shuffle', 'Volume'};

  // position is polled by clients while everything else arrives as a signal
  static const _watched = [
    'PlaybackStatus',
    'LoopStatus',
    'Shuffle',
    'Metadata',
    'Volume',
    'CanGoNext',
    'CanGoPrevious',
    'CanPlay',
    'CanPause',
    'CanSeek',
  ];

  final Map<String, DBusValue> _last = {};
  String? _artTrack;
  Uri? _art;
  bool _seeded = false;

  // without this a rejected call never reaches the client
  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    try {
      if (methodCall.interface == _root) {
        switch (methodCall.name) {
          case 'Raise':
            TrayService.instance.show();
            return DBusMethodSuccessResponse();
          case 'Quit':
            TrayService.instance.quit();
            return DBusMethodSuccessResponse();
        }
        return DBusMethodErrorResponse.unknownMethod();
      }
      if (methodCall.interface == _player) return _playerCall(methodCall);
      return DBusMethodErrorResponse.unknownInterface();
    } catch (e) {
      debugPrint('mpris call failed: $e');
      return DBusMethodErrorResponse.failed(e.toString());
    }
  }

  // client tools guess argument types unless the interfaces are declared
  @override
  List<DBusIntrospectInterface> introspect() => [
        DBusIntrospectInterface(_root,
            methods: [
              DBusIntrospectMethod('Raise'),
              DBusIntrospectMethod('Quit'),
            ],
            properties: [
              for (final entry in _rootTypes.entries)
                DBusIntrospectProperty(entry.key, DBusSignature(entry.value),
                    access: DBusPropertyAccess.read),
            ]),
        DBusIntrospectInterface(
          _player,
          methods: [
            DBusIntrospectMethod('Play'),
            DBusIntrospectMethod('Pause'),
            DBusIntrospectMethod('PlayPause'),
            DBusIntrospectMethod('Stop'),
            DBusIntrospectMethod('Next'),
            DBusIntrospectMethod('Previous'),
            DBusIntrospectMethod('Seek', args: [
              DBusIntrospectArgument(DBusSignature('x'),
                  DBusArgumentDirection.in_,
                  name: 'Offset'),
            ]),
            DBusIntrospectMethod('SetPosition', args: [
              DBusIntrospectArgument(DBusSignature('o'),
                  DBusArgumentDirection.in_,
                  name: 'TrackId'),
              DBusIntrospectArgument(DBusSignature('x'),
                  DBusArgumentDirection.in_,
                  name: 'Position'),
            ]),
            DBusIntrospectMethod('OpenUri', args: [
              DBusIntrospectArgument(DBusSignature('s'),
                  DBusArgumentDirection.in_,
                  name: 'Uri'),
            ]),
          ],
          properties: [
            for (final entry in _playerTypes.entries)
              DBusIntrospectProperty(entry.key, DBusSignature(entry.value),
                  access: _writable.contains(entry.key)
                      ? DBusPropertyAccess.readwrite
                      : DBusPropertyAccess.read),
          ],
          signals: [
            DBusIntrospectSignal('Seeked', args: [
              DBusIntrospectArgument(DBusSignature('x'),
                  DBusArgumentDirection.out,
                  name: 'Position'),
            ]),
          ],
        ),
      ];

  Future<DBusMethodResponse> _playerCall(DBusMethodCall call) async {
    switch (call.name) {
      case 'Play':
        if (audio.currentTrack == null) break;
        if (!audio.isPlaying) await audio.togglePlayPause();
      case 'Pause':
        if (audio.isPlaying) await audio.togglePlayPause();
      case 'PlayPause':
        if (audio.currentTrack == null) break;
        await audio.togglePlayPause();
      case 'Stop':
        await audio.stop();
      case 'Next':
        await audio.skipNext();
      case 'Previous':
        await audio.skipPrevious();
      case 'Seek':
        if (audio.currentTrack == null) break;
        if (call.values.length != 1 || call.values.first is! DBusInt64) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        final offset = call.values.first.asInt64();
        await _seek(audio.position + Duration(microseconds: offset));
      case 'SetPosition':
        if (audio.currentTrack == null) break;
        if (call.values.length != 2 || call.values.last is! DBusInt64) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        await _seek(Duration(microseconds: call.values.last.asInt64()));
      case 'OpenUri':
        return DBusMethodErrorResponse.notSupported();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
    return DBusMethodSuccessResponse();
  }

  Future<void> _seek(Duration target) async {
    var wanted = target;
    if (wanted < Duration.zero) wanted = Duration.zero;
    final total = audio.duration;
    if (total > Duration.zero && wanted > total) wanted = total;
    await audio.seek(wanted);
    await emitSignal(_player, 'Seeked', [DBusInt64(wanted.inMicroseconds)]);
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final value = await _value(interface, name);
    if (value == null) return DBusMethodErrorResponse.unknownProperty();
    return DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    final values = <String, DBusValue>{};
    for (final name in _names(interface)) {
      final value = await _value(interface, name);
      if (value != null) values[name] = value;
    }
    return DBusGetAllPropertiesResponse(values);
  }

  @override
  Future<DBusMethodResponse> setProperty(
      String interface, String name, DBusValue value) async {
    if (interface == _player && name == 'LoopStatus' && value is DBusString) {
      audio.setRepeatMode(switch (value.asString()) {
        'Track' => RepeatMode.one,
        'Playlist' => RepeatMode.all,
        _ => RepeatMode.off,
      });
      return DBusMethodSuccessResponse();
    }
    if (interface == _player && name == 'Shuffle' && value is DBusBoolean) {
      final mode = value.asBoolean() ? ShuffleMode.songs : ShuffleMode.off;
      audio.setShuffleMode(mode);
      return DBusMethodSuccessResponse();
    }
    if (interface == _player && name == 'Volume' && value is DBusDouble) {
      await audio.setMasterVolume(value.asDouble());
      return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.propertyReadOnly();
  }

  // seeds the cache first so a fresh connect does not look like a change
  Future<void> push() async {
    final changed = <String, DBusValue>{};
    for (final name in _watched) {
      final value = await _playerValue(name);
      if (value == null) continue;
      if (_last[name] == value) continue;
      _last[name] = value;
      if (_seeded) changed[name] = value;
    }
    _seeded = true;
    if (changed.isEmpty) return;
    try {
      await emitPropertiesChanged(_player, changedProperties: changed);
    } catch (e) {
      debugPrint('mpris signal failed: $e');
    }
  }

  Future<DBusValue?> _value(String interface, String name) async {
    if (interface == _root) return _rootValue(name);
    if (interface == _player) return _playerValue(name);
    return null;
  }

  List<String> _names(String interface) {
    if (interface == _root) return _rootTypes.keys.toList();
    if (interface == _player) return _playerTypes.keys.toList();
    return const [];
  }

  DBusValue? _rootValue(String name) {
    switch (name) {
      case 'CanQuit':
        return const DBusBoolean(true);
      case 'CanRaise':
        return const DBusBoolean(true);
      case 'HasTrackList':
        return const DBusBoolean(false);
      case 'Identity':
        return const DBusString('Kashou');
      case 'DesktopEntry':
        return const DBusString('com.libreamp.kashou');
      case 'SupportedUriSchemes':
        return DBusArray(DBusSignature('s'));
      case 'SupportedMimeTypes':
        return DBusArray(DBusSignature('s'));
    }
    return null;
  }

  Future<DBusValue?> _playerValue(String name) async {
    switch (name) {
      case 'PlaybackStatus':
        return DBusString(_status());
      case 'LoopStatus':
        return DBusString(_loopStatus());
      case 'Shuffle':
        return DBusBoolean(audio.shuffleMode != ShuffleMode.off);
      case 'Rate':
      case 'MinimumRate':
      case 'MaximumRate':
        return const DBusDouble(1.0);
      case 'Volume':
        return DBusDouble(audio.masterVolume);
      case 'Metadata':
        return DBusDict.stringVariant(await _metadata());
      case 'Position':
        return DBusInt64(audio.position.inMicroseconds);
      case 'CanGoNext':
        return DBusBoolean(audio.queue.length > 1);
      case 'CanGoPrevious':
        return DBusBoolean(audio.queue.isNotEmpty);
      case 'CanPlay':
      case 'CanPause':
      case 'CanSeek':
        return DBusBoolean(audio.currentTrack != null);
      case 'CanControl':
        return const DBusBoolean(true);
    }
    return null;
  }

  String _status() {
    if (audio.currentTrack == null) return 'Stopped';
    return audio.isPlaying ? 'Playing' : 'Paused';
  }

  String _loopStatus() => switch (audio.repeatMode) {
        RepeatMode.one => 'Track',
        RepeatMode.all => 'Playlist',
        RepeatMode.off => 'None',
      };

  Future<Map<String, DBusValue>> _metadata() async {
    final track = audio.currentTrack;
    if (track == null) return {};
    if (_artTrack != track.id) {
      _artTrack = track.id;
      _art = await artUri(track);
    }
    final total = audio.duration > Duration.zero
        ? audio.duration
        : track.duration;
    final url = track.sourceUrl ?? (track.path.isEmpty ? null : track.path);
    return {
      'mpris:trackid': DBusObjectPath(
          '/org/mpris/MediaPlayer2/Track/${track.id.hashCode.toUnsigned(32)}'),
      'xesam:title': DBusString(track.title),
      if (track.artist.isNotEmpty)
        'xesam:artist':
            DBusArray(DBusSignature('s'), [DBusString(track.artist)]),
      if (track.album.isNotEmpty) 'xesam:album': DBusString(track.album),
      if (total > Duration.zero)
        'mpris:length': DBusInt64(total.inMicroseconds),
      if (url != null) 'xesam:url': DBusString(url),
      if (_art != null) 'mpris:artUrl': DBusString(_art.toString()),
    };
  }
}

// a second instance has to leave the name to the first one
Future<MprisObject?> startMpris(
    AudioProvider audio, Future<Uri?> Function(Track track) artUri) async {
  try {
    final bus = DBusClient.session();
    final object = MprisObject(audio, artUri);
    // the shell queries the moment the name appears so identity must be ready
    await bus.registerObject(object);
    final reply = await bus.requestName(_busName);
    if (reply != DBusRequestNameReply.primaryOwner) {
      await bus.unregisterObject(object);
      await bus.close();
      return null;
    }
    return object;
  } catch (e) {
    debugPrint('mpris setup failed: $e');
    return null;
  }
}
