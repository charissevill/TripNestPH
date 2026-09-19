import 'package:flutter/material.dart';

import 'package:tripnest_ph/ai/models/ai_message.dart';
import 'package:tripnest_ph/ai/widgets/chat_bubble.dart';
import 'package:tripnest_ph/ai/widgets/chat_input_bar.dart';

import 'layout_harness.dart';

/// Chat bubbles with the content shapes an LLM actually returns: long
/// unbroken strings, wide markdown tables, code blocks and multi-day plans.
void main() {
  const table = '''
| Day | Morning activity | Afternoon activity | Estimated budget per person |
|-----|------------------|--------------------|-----------------------------|
| 1 | Chocolate Hills viewing deck | Tarsier Sanctuary in Corella | PHP 1,500 |
| 2 | Loboc River lunch cruise | Panglao Island beach hopping | PHP 2,200 |
''';
  const plan = '''
Destination: Bohol, Bohol

**Day 1 - Countryside**
- Visit the Chocolate Hills and the Bilar Man-made Forest before lunch at a local carinderia.
- Sunset at Alona Beach

**Day 2 - Islands**
- Island hopping in Balicasag and Virgin Island with a snorkeling stop.
''';
  final messages = <String, AiChatMessage>{
    'user long word': AiChatMessage(
      id: 'u1',
      role: AiMessageRole.user,
      content: 'https://www.example.com/a/very/long/unbroken/url/that/keeps/going/and/going/forever/and/ever?query=abcdefghijklmnopqrstuvwxyz',
      createdAt: DateTime(2026),
    ),
    'assistant table': AiChatMessage(id: 'a1', role: AiMessageRole.assistant, content: table, createdAt: DateTime(2026)),
    'assistant code': AiChatMessage(
      id: 'a2',
      role: AiMessageRole.assistant,
      content: '```\nfinal itinerary = planTrip(destination: "Bohol", days: 3, budget: 15000, travelers: 2);\n```',
      createdAt: DateTime(2026),
    ),
    'assistant plan': AiChatMessage(id: 'a3', role: AiMessageRole.assistant, content: plan, createdAt: DateTime(2026)),
  };

  for (final e in messages.entries) {
    layoutMatrix(
      'Chat bubble: ${e.key}',
      () => Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [ChatBubble(message: e.value, onOpenPlanner: () {})],
        ),
      ),
    );
  }

  layoutMatrix(
    'Chat input bar',
    () => Scaffold(
      body: Column(children: [const Spacer(), ChatInputBar(onSend: (_) {}, enabled: true)]),
    ),
  );
}
