/// How a field read off a permit photo compares with what the applicant
/// typed — a hint for the reviewing admin, never a verdict: OCR misreads
/// letters and people abbreviate, so a [differs] means "look closer", not
/// "fraud".
enum PermitMatch { matches, differs, unknown }

// Words that carry no identity on their own, so they shouldn't count toward
// (or against) a match.
const _noise = {'the', 'and', 'of', 'inc', 'corp', 'co', 'ltd', 'philippines', 'city', 'municipality', 'province', 'brgy', 'barangay'};

Set<String> _tokens(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r"['’`]"), '')
    .split(RegExp(r'[^a-z0-9ñ]+'))
    .where((t) => t.isNotEmpty && !_noise.contains(t))
    .toSet();

/// For a name (business or person): a match when every word of the shorter
/// one appears in the longer — so "Cha's Flowershop" matches "Chas
/// Flowershop and Gifts", and "Charisse Villarama" matches "Charisse D.
/// Villarama". [unknown] when either side is empty.
PermitMatch matchPermitName(String onPermit, String typed) {
  final a = _tokens(onPermit);
  final b = _tokens(typed);
  if (a.isEmpty || b.isEmpty) return PermitMatch.unknown;
  final shorter = a.length <= b.length ? a : b;
  final longer = identical(shorter, a) ? b : a;
  return longer.containsAll(shorter) ? PermitMatch.matches : PermitMatch.differs;
}

/// For the permit's address against the pinned location's resolved name.
/// Looser than [matchPermitName] on purpose: a reverse-geocoded pin rarely
/// repeats the house number or postal code, so sharing two place words
/// (e.g. the barangay and the town) is enough.
PermitMatch matchPermitAddress(String onPermit, String pinned) {
  bool isPlaceWord(String t) => t.length >= 3 && int.tryParse(t) == null;
  final a = _tokens(onPermit).where(isPlaceWord).toSet();
  final b = _tokens(pinned).where(isPlaceWord).toSet();
  if (a.isEmpty || b.isEmpty) return PermitMatch.unknown;
  final shared = a.intersection(b).length;
  final needed = a.length < 2 || b.length < 2 ? 1 : 2;
  return shared >= needed ? PermitMatch.matches : PermitMatch.differs;
}

/// True once [validUntil] (the permit's last valid day) has fully passed.
bool isPermitExpired(DateTime validUntil, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return DateTime(today.year, today.month, today.day).isAfter(DateTime(validUntil.year, validUntil.month, validUntil.day));
}
