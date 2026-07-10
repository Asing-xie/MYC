CREATE TYPE "ContactStatus" AS ENUM ('PENDING', 'ACCEPTED', 'BLOCKED');
CREATE TYPE "ConversationType" AS ENUM ('DIRECT');
CREATE TYPE "MessageType" AS ENUM ('TEXT', 'IMAGE', 'VOICE');
CREATE TYPE "MessageStatus" AS ENUM ('SENT', 'DELIVERED');

CREATE TABLE "User" (
  "id" TEXT NOT NULL,
  "email" TEXT,
  "phone" TEXT,
  "passwordHash" TEXT NOT NULL,
  "nickname" TEXT NOT NULL,
  "avatarUrl" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "Contact" (
  "id" TEXT NOT NULL,
  "requesterId" TEXT NOT NULL,
  "addresseeId" TEXT NOT NULL,
  "status" "ContactStatus" NOT NULL DEFAULT 'ACCEPTED',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Contact_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "Conversation" (
  "id" TEXT NOT NULL,
  "type" "ConversationType" NOT NULL DEFAULT 'DIRECT',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Conversation_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ConversationMember" (
  "id" TEXT NOT NULL,
  "conversationId" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "lastReadAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ConversationMember_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "Message" (
  "id" TEXT NOT NULL,
  "conversationId" TEXT NOT NULL,
  "senderId" TEXT NOT NULL,
  "type" "MessageType" NOT NULL,
  "content" TEXT,
  "status" "MessageStatus" NOT NULL DEFAULT 'SENT',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "Message_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "MessageReceipt" (
  "id" TEXT NOT NULL,
  "messageId" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "deliveredAt" TIMESTAMP(3),
  "readAt" TIMESTAMP(3),
  CONSTRAINT "MessageReceipt_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "Attachment" (
  "id" TEXT NOT NULL,
  "messageId" TEXT,
  "ownerId" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  "url" TEXT NOT NULL,
  "key" TEXT,
  "size" INTEGER,
  "duration" INTEGER,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "Attachment_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "User_email_key" ON "User"("email");
CREATE UNIQUE INDEX "User_phone_key" ON "User"("phone");
CREATE UNIQUE INDEX "Contact_requesterId_addresseeId_key" ON "Contact"("requesterId", "addresseeId");
CREATE UNIQUE INDEX "ConversationMember_conversationId_userId_key" ON "ConversationMember"("conversationId", "userId");
CREATE INDEX "Message_conversationId_createdAt_idx" ON "Message"("conversationId", "createdAt");
CREATE UNIQUE INDEX "MessageReceipt_messageId_userId_key" ON "MessageReceipt"("messageId", "userId");

ALTER TABLE "Contact" ADD CONSTRAINT "Contact_requesterId_fkey" FOREIGN KEY ("requesterId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Contact" ADD CONSTRAINT "Contact_addresseeId_fkey" FOREIGN KEY ("addresseeId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ConversationMember" ADD CONSTRAINT "ConversationMember_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "Conversation"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ConversationMember" ADD CONSTRAINT "ConversationMember_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Message" ADD CONSTRAINT "Message_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES "Conversation"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Message" ADD CONSTRAINT "Message_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "MessageReceipt" ADD CONSTRAINT "MessageReceipt_messageId_fkey" FOREIGN KEY ("messageId") REFERENCES "Message"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "MessageReceipt" ADD CONSTRAINT "MessageReceipt_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Attachment" ADD CONSTRAINT "Attachment_messageId_fkey" FOREIGN KEY ("messageId") REFERENCES "Message"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "Attachment" ADD CONSTRAINT "Attachment_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
