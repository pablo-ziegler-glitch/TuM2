import type { Timestamp } from 'firebase/firestore';

export type UserRole = 'customer' | 'owner' | 'admin' | 'super_admin';
export type UserStatus = 'active' | 'pending' | 'blocked';

/**
 * Nivel de confianza del usuario. Alimenta scoring comunitario y
 * publicación semi-automática de contribuciones (V1.1+).
 */
export type TrustLevel = 'new' | 'contributor' | 'trusted' | 'verified';

/**
 * Collection: users/{userId}
 * Documento canónico de identidad del sistema.
 * El role es controlado server-side exclusivamente.
 */
export interface UserDocument {
  // Obligatorios
  id: string;
  email: string;
  displayName: string;
  role: UserRole;
  status: UserStatus;
  trustScore: number;
  trustLevel: TrustLevel;
  gamificationEnabled: boolean;
  isVerified: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Opcionales
  username: string | null;
  phone: string | null;
  defaultZoneId: string | null;
  /** Localidad principal declarada (ej: "Carlos Spegazzini") */
  primaryLocality: string | null;
  /** Municipio / partido (ej: "Ezeiza") */
  party: string | null;
  /** Provincia (ej: "Buenos Aires") */
  province: string | null;
  profileCompleted: boolean;
  lastLoginAt: Timestamp | null;
  lastActiveAt: Timestamp | null;
}
