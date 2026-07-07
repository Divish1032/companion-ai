import 'package:flutter/material.dart';

void main() {
  runApp(const CompanionApp());
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Companion AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
      ),
      home: const VoiceHomeScreen(),
    );
  }
}

class VoiceHomeScreen extends StatefulWidget {
  const VoiceHomeScreen({super.key});

  @override
  State<VoiceHomeScreen> createState() => _VoiceHomeScreenState();
}

class _VoiceHomeScreenState extends State<VoiceHomeScreen> {
  bool _sessionActive = false;

  void _toggleSession() {
    setState(() {
      _sessionActive = !_sessionActive;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _sessionActive ? 'Session placeholder active' : 'Ready';

    return Scaffold(
      appBar: AppBar(title: const Text('Companion AI')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sessionActive ? Icons.graphic_eq : Icons.mic_none,
                        color: theme.colorScheme.primary,
                        size: 72,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        status,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Voice-only Sprint 0 shell. LiveKit, microphone, and provider integrations start in later sprints.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton.icon(
                onPressed: _toggleSession,
                icon: Icon(_sessionActive ? Icons.stop : Icons.mic),
                label: Text(
                  _sessionActive ? 'End placeholder' : 'Start placeholder',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
