import 'package:companion_mobile/features/livekit_session/domain/livekit_data_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes, decodes, and preserves event sequence fields', () {
    const event = LiveKitDataEvent(
      type: 'session_state',
      sequence: 7,
      sessionId: 'session_1',
      turnId: 'turn_1',
      timestampMs: 123,
      payload: {'state': 'listening'},
    );

    final decoded = LiveKitDataEvent.decode(event.encode());

    expect(decoded.type, 'session_state');
    expect(decoded.sequence, 7);
    expect(decoded.sessionId, 'session_1');
    expect(decoded.turnId, 'turn_1');
    expect(decoded.payload['state'], 'listening');
  });

  test('deduplicates by session, turn, and sequence', () {
    final deduplicator = LiveKitEventDeduplicator();
    const first = LiveKitDataEvent(
      type: 'transcript_final',
      sequence: 10,
      sessionId: 'session_1',
      turnId: 'turn_1',
      timestampMs: 1,
    );
    const duplicate = LiveKitDataEvent(
      type: 'error',
      sequence: 10,
      sessionId: 'session_1',
      turnId: 'turn_1',
      timestampMs: 2,
    );
    const nextTurn = LiveKitDataEvent(
      type: 'transcript_final',
      sequence: 10,
      sessionId: 'session_1',
      turnId: 'turn_2',
      timestampMs: 3,
    );

    expect(deduplicator.shouldAccept(first), isTrue);
    expect(deduplicator.shouldAccept(duplicate), isFalse);
    expect(deduplicator.shouldAccept(nextTurn), isTrue);
  });

  test('sequencer assigns increasing sequence numbers', () {
    final sequencer = LiveKitEventSequencer();

    final first = sequencer.next(type: 'a', sessionId: 'session_1');
    final second = sequencer.next(type: 'b', sessionId: 'session_1');

    expect(first.sequence, 1);
    expect(second.sequence, 2);
  });
}
