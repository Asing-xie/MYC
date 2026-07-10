CREATE TYPE "ConversationMemberRole" AS ENUM ('OWNER', 'MEMBER');

ALTER TABLE "ConversationMember"
ADD COLUMN "role" "ConversationMemberRole" NOT NULL DEFAULT 'MEMBER';

WITH first_group_members AS (
  SELECT DISTINCT ON (cm."conversationId") cm."id"
  FROM "ConversationMember" cm
  INNER JOIN "Conversation" c ON c."id" = cm."conversationId"
  WHERE c."type" = 'GROUP'
  ORDER BY cm."conversationId", cm."createdAt" ASC, cm."id" ASC
)
UPDATE "ConversationMember"
SET "role" = 'OWNER'
WHERE "id" IN (SELECT "id" FROM first_group_members);
