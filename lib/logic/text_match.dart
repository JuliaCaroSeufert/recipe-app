// Tolerant text matching for dislikes/ingredients so that spelling, case,
// umlauts, hyphens, spaces and singular/plural don't matter.
//
// "Pak Choi", "pak choi", "pakchoi" and "pak-choi" all normalise to the same
// thing, and a dislike matches an ingredient if either contains the other.

const Map<String, String> _fold = {
  'ä': 'a', 'ö': 'o', 'ü': 'u', 'ß': 'ss',
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

/// Lower-cases, folds umlauts/accents and keeps only letters, digits and
/// single spaces.
String normalizeTerm(String s) {
  final lower = s.toLowerCase().trim();
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    buf.write(_fold[ch] ?? ch);
  }
  return buf
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Expands a term into comparable forms: the whole string without spaces, and
/// each individual word. Lets "frühlingszwiebel" be hit by "zwiebel" etc.
Set<String> expandTerm(String term) {
  final n = normalizeTerm(term);
  final out = <String>{};
  final spaceless = n.replaceAll(' ', '');
  if (spaceless.isNotEmpty) out.add(spaceless);
  for (final w in n.split(' ')) {
    if (w.length >= 2) out.add(w);
  }
  return out;
}

/// True if any needle form matches any haystack form — exact for short terms,
/// bidirectional substring for terms of length >= 3 (covers plural/compounds).
bool matchesAny(Set<String> haystack, Set<String> needles) {
  for (final needle in needles) {
    for (final hay in haystack) {
      if (needle == hay) return true;
      if (needle.length >= 3 && (hay.contains(needle) || needle.contains(hay))) {
        return true;
      }
    }
  }
  return false;
}
