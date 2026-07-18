-- AlterTable
ALTER TABLE "platform_config" ADD COLUMN     "discovery_radius_m" INTEGER NOT NULL DEFAULT 3000;

-- CreateTable
CREATE TABLE "service_interest" (
    "id" UUID NOT NULL,
    "lat" DOUBLE PRECISION NOT NULL,
    "lng" DOUBLE PRECISION NOT NULL,
    "phone" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "service_interest_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "service_interest_created_at_idx" ON "service_interest"("created_at");
