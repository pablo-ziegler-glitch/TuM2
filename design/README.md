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

### React Native / Expo (mobile — TuM2-0052)

```ts
import tokens from '../../design/tokens.json';

const colors = {
  primary: tokens.color.primary.value,
  primaryLight: tokens.color.primary.shades['100'],
  secondary: tokens.color.secondary.value,
  // ...
};
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
