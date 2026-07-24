/// One entry in the "What's New" version history.
class AppUpdate {
  const AppUpdate({required this.version, required this.date, required this.highlights});

  final String version;
  final String date;
  final List<String> highlights;
}
