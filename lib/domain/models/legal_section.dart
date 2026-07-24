/// One heading + optional paragraph + optional bullet list within a legal
/// document (Privacy Policy, Terms of Service) — lets the screen render
/// real typographic hierarchy instead of one long block of plain text.
class LegalSection {
  const LegalSection({required this.heading, this.paragraph, this.bullets = const []});

  final String heading;
  final String? paragraph;
  final List<String> bullets;
}

/// A single Q&A pair for the FAQ screen, grouped by [category] so the list
/// can be filtered and rendered under section headers.
class FaqItem {
  const FaqItem({required this.category, required this.question, required this.answer});

  final String category;
  final String question;
  final String answer;
}
