// Maps source-specific category tokens to TuM2 canonical categories.

const GOOGLE_PLACES_TO_TUM2: Record<string, string> = {
  pharmacy: "farmacia",
  drugstore: "farmacia",
  convenience_store: "kiosco",
  grocery_or_supermarket: "almacen",
  supermarket: "supermercado",
  bakery: "panaderia",
  butcher: "carniceria",
  liquor_store: "licoreria",
  hardware_store: "ferreteria",
  veterinary_care: "veterinaria",
  pet_store: "veterinaria",
  restaurant: "restaurante",
  food: "restaurante",
  cafe: "cafeteria",
  bar: "bar",
  laundry: "lavanderia",
  book_store: "libreria",
  shoe_store: "zapateria",
  clothing_store: "indumentaria",
  electronics_store: "electronica",
  florist: "floreria",
  hair_care: "peluqueria",
  beauty_salon: "estetica",
  gym: "gimnasio",
  physiotherapist: "kinesiologia",
  doctor: "medico",
  dentist: "dentista",
  hospital: "clinica",
  bank: "banco",
  atm: "cajero_automatico",
  gas_station: "estacion_de_servicio",
  car_repair: "taller_mecanico",
  car_wash: "lavadero",
  locksmith: "cerrajeria",
  electrician: "electricista",
  plumber: "plomero",
};

const FALLBACK_CATEGORY = "comercio_general";

/**
 * Normalizes a raw category string from an external source into a TuM2 canonical category.
 * For Google Places, `rawCategory` may be a comma-separated list of types.
 */
export function normalizeExternalCategory(
  sourceType: string,
  rawCategory: string
): string {
  if (sourceType === "google_places") {
    const types = rawCategory
      .split(",")
      .map((t) => t.trim().toLowerCase());

    for (const type of types) {
      const mapped = GOOGLE_PLACES_TO_TUM2[type];
      if (mapped) return mapped;
    }
  }

  // Generic fallback: try direct match
  const lower = rawCategory.toLowerCase().trim();
  const directMatch = GOOGLE_PLACES_TO_TUM2[lower];
  if (directMatch) return directMatch;

  return FALLBACK_CATEGORY;
}
