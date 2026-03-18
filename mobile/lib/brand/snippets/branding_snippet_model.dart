import 'package:cloud_firestore/cloud_firestore.dart';

enum SnippetContextType {
  loading,
  emptyState,
  onboarding,
  notification,
  badge,
}

enum SnippetSegment { owner, customer, all }

class BrandingSnippet {
  final String id;
  final SnippetContextType contextType;
  final SnippetSegment segment;
  final String tone;
  final String text;
  final bool active;
  final int version;

  const BrandingSnippet({
    required this.id,
    required this.contextType,
    required this.segment,
    required this.tone,
    required this.text,
    required this.active,
    required this.version,
  });

  factory BrandingSnippet.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BrandingSnippet(
      id: doc.id,
      contextType: _parseContextType(data['contextType'] as String? ?? ''),
      segment: _parseSegment(data['segment'] as String? ?? 'all'),
      tone: data['tone'] as String? ?? '',
      text: data['text'] as String? ?? '',
      active: data['active'] as bool? ?? true,
      version: data['version'] as int? ?? 1,
    );
  }

  static SnippetContextType _parseContextType(String value) {
    switch (value) {
      case 'loading':
        return SnippetContextType.loading;
      case 'empty_state':
        return SnippetContextType.emptyState;
      case 'onboarding':
        return SnippetContextType.onboarding;
      case 'notification':
        return SnippetContextType.notification;
      case 'badge':
        return SnippetContextType.badge;
      default:
        return SnippetContextType.loading;
    }
  }

  static SnippetSegment _parseSegment(String value) {
    switch (value) {
      case 'OWNER':
        return SnippetSegment.owner;
      case 'CUSTOMER':
        return SnippetSegment.customer;
      default:
        return SnippetSegment.all;
    }
  }
}
