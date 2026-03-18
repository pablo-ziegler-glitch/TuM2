import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'snippets/branding_snippet_model.dart';

/// Streams all active branding snippets from Firestore.
final brandingSnippetsProvider =
    StreamProvider<List<BrandingSnippet>>((ref) {
  return FirebaseFirestore.instance
      .collection('brandingSnippets')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map((doc) => BrandingSnippet.fromFirestore(doc)).toList());
});

/// Returns a random snippet for a given context type, filtered by segment.
/// Falls back to static copy if Firestore snippets are unavailable.
extension BrandingSnippetFilter on List<BrandingSnippet> {
  BrandingSnippet? forContext(
    SnippetContextType contextType, {
    SnippetSegment segment = SnippetSegment.all,
  }) {
    final matching = where((s) =>
        s.contextType == contextType &&
        (s.segment == SnippetSegment.all || s.segment == segment)).toList();

    if (matching.isEmpty) return null;
    matching.shuffle();
    return matching.first;
  }
}

/// Static fallback copy for loading states
const kLoadingCopies = [
  'Buscando en tu zona...',
  'Cargando el barrio...',
  'Un momento, ya aparece...',
];

/// Static fallback copy for empty states
const kEmptyDiscoverCopies = [
  'No encontramos comercios por acá. ¿Sos dueño de uno?',
  'El barrio está esperando sus primeros comercios.',
  'Aún no hay resultados, pero el barrio crece cada día.',
];
