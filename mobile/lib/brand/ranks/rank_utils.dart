import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// TuM2 rank system utilities
/// Ranks: Vecino → Explorador → Referente → Conector → Radar
class RankUtils {
  RankUtils._();

  static const Map<String, int> thresholds = {
    'Radar': 5000,
    'Conector': 1500,
    'Referente': 500,
    'Explorador': 100,
    'Vecino': 0,
  };

  /// Calculates the rank based on XP points.
  static String calculateRank(int xpPoints) {
    if (xpPoints >= 5000) return 'Radar';
    if (xpPoints >= 1500) return 'Conector';
    if (xpPoints >= 500) return 'Referente';
    if (xpPoints >= 100) return 'Explorador';
    return 'Vecino';
  }

  /// Returns XP needed to reach the next rank, or null if at max rank.
  static int? xpToNextRank(int currentXp) {
    if (currentXp >= 5000) return null;
    if (currentXp >= 1500) return 5000 - currentXp;
    if (currentXp >= 500) return 1500 - currentXp;
    if (currentXp >= 100) return 500 - currentXp;
    return 100 - currentXp;
  }

  /// Returns progress (0.0 to 1.0) within the current rank tier.
  static double progressInCurrentTier(int xpPoints) {
    if (xpPoints >= 5000) return 1.0;
    if (xpPoints >= 1500) {
      return (xpPoints - 1500) / (5000 - 1500);
    }
    if (xpPoints >= 500) {
      return (xpPoints - 500) / (1500 - 500);
    }
    if (xpPoints >= 100) {
      return (xpPoints - 100) / (500 - 100);
    }
    return xpPoints / 100;
  }

  /// Returns the color associated with each rank.
  static Color rankColor(String rank) {
    switch (rank) {
      case 'Radar':
        return const Color(0xFFFF6B35);
      case 'Conector':
        return const Color(0xFF7C3AED);
      case 'Referente':
        return const Color(0xFF1A6BFF);
      case 'Explorador':
        return const Color(0xFF16A34A);
      case 'Vecino':
      default:
        return TuM2Colors.onSurfaceVariant;
    }
  }

  /// Returns the emoji/icon associated with each rank.
  static String rankEmoji(String rank) {
    switch (rank) {
      case 'Radar':
        return '📡';
      case 'Conector':
        return '🔗';
      case 'Referente':
        return '⭐';
      case 'Explorador':
        return '🧭';
      case 'Vecino':
      default:
        return '🏠';
    }
  }

  /// Returns a short description for each rank.
  static String rankDescription(String rank) {
    switch (rank) {
      case 'Radar':
        return 'Conocés el barrio mejor que nadie';
      case 'Conector':
        return 'Tu voz mueve el comercio local';
      case 'Referente':
        return 'El barrio te escucha';
      case 'Explorador':
        return 'Empezás a descubrir TuM2';
      case 'Vecino':
      default:
        return 'Bienvenido a tu cuadra digital';
    }
  }
}
