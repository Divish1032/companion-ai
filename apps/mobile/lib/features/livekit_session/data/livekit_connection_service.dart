import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../domain/livekit_data_event.dart';
import 'session_api_client.dart';

final liveKitConnectionServiceProvider = Provider<LiveKitConnectionService>(
  (ref) => LiveKitConnectionService(),
);

enum LiveKitConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class LiveKitSessionHandle {
  LiveKitSessionHandle({
    required this.session,
    required this.connectionUpdates,
    required this.events,
  });

  final LiveKitSessionInfo session;
  final Stream<LiveKitConnectionStatus> connectionUpdates;
  final Stream<LiveKitDataEvent> events;
}

class LiveKitConnectionService {
  static const _connectTimeout = Duration(seconds: 15);
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  final _connectionController =
      StreamController<LiveKitConnectionStatus>.broadcast();
  final _eventController = StreamController<LiveKitDataEvent>.broadcast();
  final _deduplicator = LiveKitEventDeduplicator();

  Stream<LiveKitConnectionStatus> get connectionUpdates =>
      _connectionController.stream;

  Stream<LiveKitDataEvent> get events => _eventController.stream;

  Future<LiveKitSessionHandle> connect({
    required LiveKitSessionInfo session,
    required LiveKitTokenInfo token,
  }) async {
    await disconnect();
    _connectionController.add(LiveKitConnectionStatus.connecting);

    final room = lk.Room(
      roomOptions: const lk.RoomOptions(
        defaultAudioCaptureOptions: lk.AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          highPassFilter: true,
          stopAudioCaptureOnMute: true,
        ),
        defaultAudioPublishOptions: lk.AudioPublishOptions(
          dtx: true,
          red: true,
          audioBitrate: 24000,
        ),
      ),
    );
    _room = room;
    _listener = room.createListener()
      ..on<lk.RoomConnectedEvent>(
        (_) => _connectionController.add(LiveKitConnectionStatus.connected),
      )
      ..on<lk.RoomReconnectingEvent>(
        (_) => _connectionController.add(LiveKitConnectionStatus.reconnecting),
      )
      ..on<lk.RoomReconnectedEvent>(
        (_) => _connectionController.add(LiveKitConnectionStatus.connected),
      )
      ..on<lk.RoomDisconnectedEvent>(
        (_) => _connectionController.add(LiveKitConnectionStatus.disconnected),
      )
      ..on<lk.TrackSubscribedEvent>((event) {
        if (event.track is lk.RemoteAudioTrack) {
          _connectionController.add(LiveKitConnectionStatus.connected);
        }
      })
      ..on<lk.DataReceivedEvent>((event) {
        try {
          final decoded = LiveKitDataEvent.decode(event.data);
          if (_deduplicator.shouldAccept(decoded)) {
            _eventController.add(decoded);
          }
        } on FormatException {
          // Ignore malformed prototype data-channel payloads.
        }
      });

    try {
      await room
          .connect(token.liveKitUrl, token.token)
          .timeout(_connectTimeout);
      await room.localParticipant?.setMicrophoneEnabled(true);
      _connectionController.add(LiveKitConnectionStatus.connected);
    } catch (_) {
      _connectionController.add(LiveKitConnectionStatus.failed);
      await disconnect();
      rethrow;
    }

    return LiveKitSessionHandle(
      session: session,
      connectionUpdates: connectionUpdates,
      events: events,
    );
  }

  Future<void> sendReliable(LiveKitDataEvent event) async {
    await _publish(event, reliable: true, topic: 'critical');
  }

  Future<void> sendLossy(LiveKitDataEvent event) async {
    await _publish(event, reliable: false, topic: 'diagnostic');
  }

  Future<void> disconnect() async {
    await _listener?.dispose();
    _listener = null;
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;
    _connectionController.add(LiveKitConnectionStatus.disconnected);
  }

  Future<void> _publish(
    LiveKitDataEvent event, {
    required bool reliable,
    required String topic,
  }) async {
    final participant = _room?.localParticipant;
    if (participant == null) {
      throw StateError('LiveKit room is not connected.');
    }
    await participant.publishData(
      event.encode(),
      reliable: reliable,
      topic: topic,
    );
  }
}
