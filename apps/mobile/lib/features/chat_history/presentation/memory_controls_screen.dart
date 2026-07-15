import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/memory_embedding_service.dart';
import '../data/objectbox_memory_vector_index.dart';

final manageableMemoriesProvider = StreamProvider<List<MemoryRecord>>((ref) {
  return ref.watch(appDatabaseProvider).watchManageableMemories();
});

class MemoryControlsScreen extends ConsumerWidget {
  const MemoryControlsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(manageableMemoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('What I remember')),
      body: memories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Could not read local memory.')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No long-term memories yet. Memories stay on this device; '
                  'the background extractor only proposes candidates.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _MemoryCard(memory: items[index]),
          );
        },
      ),
    );
  }
}

class _MemoryCard extends ConsumerWidget {
  const _MemoryCard({required this.memory});

  final MemoryRecord memory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final needsConfirmation = memory.receiptState == 'unconfirmed';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _Tag(memory.kind.replaceAll('_', ' ')),
                _Tag(memory.temporalStatus),
                if (needsConfirmation) const _Tag('needs confirmation'),
              ],
            ),
            const SizedBox(height: 10),
            Text(memory.content, style: theme.textTheme.bodyMedium),
            if (memory.evidenceSummary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(memory.evidenceSummary, style: theme.textTheme.bodySmall),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (needsConfirmation)
                  TextButton.icon(
                    onPressed: () => _confirm(ref),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Confirm'),
                  ),
                TextButton.icon(
                  onPressed: () => _forget(context, ref),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Forget'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _forget(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget this memory?'),
        content: const Text('This removes the memory from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final vectorIndex = await ref.read(memoryVectorIndexProvider.future);
        try {
          await vectorIndex.delete(memory.id);
        } catch (_) {
          // Vectors are derived. If targeted deletion fails, clearing the
          // rebuildable index is safer than leaving a deleted memory vector.
          await vectorIndex.deleteAll();
        }
      } finally {
        await ref.read(appDatabaseProvider).forgetMemory(memory.id);
      }
    }
  }

  Future<void> _confirm(WidgetRef ref) async {
    await ref.read(appDatabaseProvider).confirmMemory(memory.id);
    final rawTurnIds = jsonDecode(memory.sourceTurnIdsJson);
    if (rawTurnIds is! List) return;
    for (final turnId in rawTurnIds.whereType<String>()) {
      await ref.read(memoryEmbeddingSyncProvider).syncTurnMemories(turnId);
    }
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}
