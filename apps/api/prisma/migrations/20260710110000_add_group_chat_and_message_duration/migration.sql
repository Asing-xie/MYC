ALTER TYPE "ConversationType" ADD VALUE 'GROUP';

ALTER TABLE "Conversation"
ADD COLUMN "title" TEXT,
ADD COLUMN "avatarUrl" TEXT;

ALTER TABLE "Message"
ADD COLUMN "durationMs" INTEGER;
