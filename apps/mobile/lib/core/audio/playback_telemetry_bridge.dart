import 'dart:async';

import 'package:flutter/services.dart';

/// Receives native output-activation timestamps, never media frames.
///
/// Android uses `AudioManager.AudioPlaybackCallback` after an agent marker has
/// armed a single turn. iOS currently reports unsupported rather than inventing
/// a render timestamp; a renderer-level iOS hook remains required for parity.
class PlaybackTelemetryBridge {
  PlaybackTelemetryBridge._();

  static final instance = PlaybackTelemetryBridge._();
  static const _methods = MethodChannel(
    'ai.companion.companion_mobile/playback_telemetry/methods',
  );
  static const _events = EventChannel(
    'ai.companion.companion_mobile/playback_telemetry/events',
  );

  Stream<PlaybackObservation>? _observations;

  Stream<PlaybackObservation> get observations {
    return _observations ??= _events
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map(
          (event) => PlaybackObservation.fromPlatform(
            Map<Object?, Object?>.from(event as Map),
          ),
        )
        .where((event) => event.turnId.isNotEmpty)
        .asBroadcastStream();
  }

  Future<void> arm(String turnId) async {
    if (turnId.isEmpty) return;
    try {
      await _methods.invokeMethod<void>('arm', {'turn_id': turnId});
    } on PlatformException {
      // Missing native capability is recorded as missing correlation, never a
      // fabricated client latency value.
    }
  }
}

class PlaybackObservation {
  const PlaybackObservation({
    required this.turnId,
    required this.timestampMs,
    required this.source,
  });

  final String turnId;
  final int timestampMs;
  final String source;

  factory PlaybackObservation.fromPlatform(Map<Object?, Object?> value) {
    return PlaybackObservation(
      turnId: value['turn_id'] as String? ?? '',
      timestampMs: value['playback_timestamp_ms'] as int? ?? 0,
      source: value['source'] as String? ?? 'unknown',
    );
  }
}
