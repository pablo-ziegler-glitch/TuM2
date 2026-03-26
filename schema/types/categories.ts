import type { Timestamp } from 'firebase/firestore';

/**
 * Collection: categories/{categoryId}
 * Categorías de comercio (tipo principal).
 *
 * Categorías core del MVP:
 *   pharmacy, veterinary, grocery, supermarket,
 *   prepared_food, fast_food, tire_shop
 */
export interface CategoryDocument {
  // Obligatorios
  id: string;
  name: string;
  slug: string;
  isActive: boolean;
  isCoreMvp: boolean;
  sortOrder: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Opcionales
  icon?: string | null;
  description?: string | null;
}

/**
 * Collection: subcategories/{subcategoryId}
 * Subcategorías dentro de una categoría principal.
 *
 * Ejemplos por categoría:
 *   pharmacy    → analgesicos, cuidado_personal, bebes, primeros_auxilios, dermocosmetica
 *   veterinary  → alimentos, antiparasitarios, higiene, accesorios, farmacia_veterinaria
 *   tire_shop   → reparacion, neumaticos, balanceo, alineacion, auxilio
 *   grocery     → bebidas, limpieza, almacen_seco, lacteos, congelados
 *   prepared_food → platos, combos, bebidas, postres, promociones
 */
export interface SubcategoryDocument {
  // Obligatorios
  id: string;
  categoryId: string;
  name: string;
  slug: string;
  isActive: boolean;
  sortOrder: number;

  // Opcionales
  description?: string | null;
}
