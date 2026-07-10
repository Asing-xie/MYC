ALTER TABLE "User" ADD COLUMN "signature" TEXT;

CREATE TABLE "UserAlbumPhoto" (
  "id" TEXT NOT NULL,
  "ownerId" TEXT NOT NULL,
  "url" TEXT NOT NULL,
  "caption" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "UserAlbumPhoto_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "UserAlbumPhoto_ownerId_createdAt_idx" ON "UserAlbumPhoto"("ownerId", "createdAt");

ALTER TABLE "UserAlbumPhoto" ADD CONSTRAINT "UserAlbumPhoto_ownerId_fkey"
  FOREIGN KEY ("ownerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
