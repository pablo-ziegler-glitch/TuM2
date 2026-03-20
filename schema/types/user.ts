import type { Timestamp } from 'firebase/firestore';

export type UserRole = 'customer' | 'owner' | 'admin' | 'super_admin';
export type UserStatus = 'active' | 'pending' | 'blocked';

/**
 * Collection: users/{userId}
 * Canonical user document. Role is controlled server-side.
 */
export interface UserDocument {
  // Required
  id: string;
  email: string;
  displayName: string;
  role: UserRole;
  status: UserStatus;
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Optional
  phone: string | null;
  defaultZoneId: string | null;
  lastLoginAt: Timestamp | null;
  profileCompleted: boolean;
}
