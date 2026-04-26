String normalizeCatalogText(String input) {
  final lower = input.toLowerCase().trim();
  if (lower.isEmpty) return '';

  const accents = <String, String>{
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  final buffer = StringBuffer();
  for (final codePoint in lower.runes) {
    final char = String.fromCharCode(codePoint);
    buffer.write(accents[char] ?? char);
  }

  return buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
