import type { Timestamp } from 'firebase/firestore';

export type ConversationStatus = 'active' | 'archived' | 'blocked';
export type ConversationType = 'user_owner';
export type MessageType = 'text' | 'image';
export type MessageStatus = 'sent' | 'delivered' | 'read';
export type MessageSenderRole = 'user' | 'owner';

/**
 * Collection: conversations/{conversationId}
 * Chat 1 a 1 entre un usuario y el dueño de un comercio reclamado.
 *
 * Solo existe si:
 *   - merchant.ownershipStatus = 'claimed'
 *   - merchant.chatEnabled = true
 *
 * participantIds permite queries array-contains eficientes.
 * La colección es privada: nunca accesible sin autenticación.
 *
 * Subcolección: conversations/{conversationId}/messages/{messageId}
 */
export interface ConversationDocument {
  // Obligatorios
  id: string;
  type: ConversationType;
  merchantId: string;
  userId: string;
  ownerUserId: string;
  /** Array [userId, ownerUserId] para queries array-contains. */
  participantIds: string[];
  status: ConversationStatus;
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Opcionales
  lastMessageText?: string | null;
  lastMessageAt?: Timestamp | null;
  lastMessageByUserId?: string | null;
  unreadCountUser?: number;
  unreadCountOwner?: number;
  archivedByUser?: boolean;
  archivedByOwner?: boolean;
}

/**
 * Subcolección: conversations/{conversationId}/messages/{messageId}
 * Al menos uno de text o imageUrl debe estar presente.
 */
export interface MessageDocument {
  // Obligatorios
  id: string;
  conversationId: string;
  senderUserId: string;
  senderRole: MessageSenderRole;
  type: MessageType;
  status: MessageStatus;
  createdAt: Timestamp;

  // Opcionales
  text?: string | null;
  imageUrl?: string | null;
}
