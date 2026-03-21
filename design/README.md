# TuM2 — Sistema de diseño

## Paleta de colores

La paleta oficial de TuM2 está definida en [`tokens.json`](./tokens.json).

### Colores base

| Token       | Hex       | Uso principal                                      |
|-------------|-----------|----------------------------------------------------|
| `primary`   | `#0E5BD8` | Acciones primarias, CTAs, links activos, botones   |
| `secondary` | `#0F766E` | Acciones secundarias, estados positivos, badges    |
| `tertiary`  | `#FF8D46` | Destacados, alertas suaves, señales operativas     |
| `neutral`   | `#C9C7B8` | Fondos, superficies, separadores, texto secundario |

### Escala de tonos

Cada color tiene una escala de 10 tonos (50–900). El valor base corresponde a:

- `primary.500` = `#0E5BD8`
- `secondary.500` = `#0F766E`
- `tertiary.500` = `#FF8D46`
- `neutral.400` = `#C9C7B8`

Los tonos **más claros (50–300)** se usan para fondos y superficies.
Los tonos **medios (400–600)** se usan para elementos interactivos.
Los tonos **oscuros (700–900)** se usan para texto y énfasis.

---

## Consumo por plataforma

### Flutter / Dart (mobile — TuM2-0052)

Los tokens se traducen a una clase `AppColors` en Dart. No se importa el JSON en runtime — se genera un archivo de constantes durante el setup del proyecto (o se mantiene a mano sincronizado con `tokens.json`).

```dart
// lib/design/app_colors.dart
import 'package:flutter/material.dart';

abstract class AppColors {
  // Primary — #0E5BD8
  static const primary = Color(0xFF0E5BD8);
  static const primary50 = Color(0xFFEBF1FD);
  static const primary100 = Color(0xFFC3D6F9);
  static const primary500 = Color(0xFF0E5BD8);
  static const primary700 = Color(0xFF083E98);

  // Secondary — #0F766E
  static const secondary = Color(0xFF0F766E);
  static const secondary50 = Color(0xFFE6F5F4);
  static const secondary500 = Color(0xFF0F766E);

  // Tertiary — #FF8D46
  static const tertiary = Color(0xFFFF8D46);
  static const tertiary50 = Color(0xFFFFF3EB);
  static const tertiary500 = Color(0xFFFF8D46);

  // Neutral — #C9C7B8
  static const neutral = Color(0xFFC9C7B8);
  static const neutral50 = Color(0xFFF9F8F6);
  static const neutral400 = Color(0xFFC9C7B8);
  static const neutral500 = Color(0xFFB0AE9F);
  static const neutral900 = Color(0xFF2D2D26);

  // Semánticos de excepción (no en tokens.json — definidos en ONBOARDING-OWNER-EXCEPTIONS.md)
  static const error = Color(0xFFDC2626);
  static const errorBg = Color(0xFFFEF2F2);
}
```

### Next.js / Tailwind (web — TuM2-0070)

En `tailwind.config.js`:

```js
const tokens = require('./design/tokens.json');

module.exports = {
  theme: {
    extend: {
      colors: {
        primary: tokens.color.primary.shades,
        secondary: tokens.color.secondary.shades,
        tertiary: tokens.color.tertiary.shades,
        neutral: tokens.color.neutral.shades,
      },
    },
  },
};
```

### Style Dictionary

Los tokens siguen la especificación de [Style Dictionary](https://styledictionary.com/) y son compatibles con Figma Tokens / Token Studio.

---

## Versionado

Los tokens de diseño se versionan junto al código. Cualquier cambio en la paleta debe:

1. Actualizarse en `tokens.json`
2. Reflejarse en este README
3. Comunicarse al equipo de diseño y mobile/web

**Versión actual:** `1.0.0` — Tarjeta TuM2-0010
