/// Pulls the distinct `**Bold**` names out of a chat reply, lowercased and
/// trimmed, in first-mention order, capped at [limit] — `AiChatScreen` looks
/// each one up against the real places/restaurants actually handed to the
/// model this turn, so a match is never a coincidence or a hallucinated
/// name that merely looks plausible. `**Bold**` is the same convention
/// `ChatPrompts.systemPrompt()` already asks the model to use for place
/// names, so this needs no new formatting instruction to work.
List<String> extractBoldNames(String content, {int limit = 4}) {
  final matches = RegExp(r'\*\*(.+?)\*\*').allMatches(content).map((m) => m.group(1)!.trim().toLowerCase());
  final result = <String>[];
  for (final name in matches) {
    if (name.isEmpty || result.contains(name)) continue;
    result.add(name);
    if (result.length >= limit) break;
  }
  return result;
}
