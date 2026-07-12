-- Gap #1: Add firebaseUid to Customer and Kitchen (unblocks Auth module)
ALTER TABLE "customers" ADD COLUMN "firebase_uid" TEXT;
CREATE UNIQUE INDEX "customers_firebase_uid_key" ON "customers"("firebase_uid");

ALTER TABLE "kitchens" ADD COLUMN "firebase_uid" TEXT;
CREATE UNIQUE INDEX "kitchens_firebase_uid_key" ON "kitchens"("firebase_uid");

-- Gap #2: Add device_tokens table (unblocks Notifications module)
CREATE TABLE "device_tokens" (
    "id" UUID NOT NULL,
    "owner_type" TEXT NOT NULL,
    "owner_id" UUID NOT NULL,
    "fcm_token" TEXT NOT NULL,
    "device_info" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "device_tokens_fcm_token_key" ON "device_tokens"("fcm_token");
CREATE INDEX "device_tokens_owner_type_owner_id_idx" ON "device_tokens"("owner_type", "owner_id");

-- Gap #3: Remove unused 'accepted' enum value from OrderStatus
-- Postgres doesn't support DROP VALUE, so rebuild the enum.
-- Safe pre-production: no rows reference 'accepted'.
ALTER TABLE "orders" ALTER COLUMN "status" TYPE TEXT;
ALTER TABLE "order_status_history" ALTER COLUMN "status" TYPE TEXT;
DROP TYPE "OrderStatus";
CREATE TYPE "OrderStatus" AS ENUM ('received', 'preparing', 'ready', 'customer_en_route', 'customer_arrived', 'out_for_delivery', 'completed', 'rejected', 'cancelled');
ALTER TABLE "orders" ALTER COLUMN "status" TYPE "OrderStatus" USING "status"::"OrderStatus";
ALTER TABLE "orders" ALTER COLUMN "status" SET DEFAULT 'received';
ALTER TABLE "order_status_history" ALTER COLUMN "status" TYPE "OrderStatus" USING "status"::"OrderStatus";

-- Gap #4: Add unique constraint on KitchenHours (kitchen_id, day_of_week)
CREATE UNIQUE INDEX "kitchen_hours_kitchen_id_day_of_week_key" ON "kitchen_hours"("kitchen_id", "day_of_week");

-- Gap #7: Add cancelledAt and cancelReason to Order (analytics gap)
ALTER TABLE "orders" ADD COLUMN "cancelled_at" TIMESTAMPTZ;
ALTER TABLE "orders" ADD COLUMN "cancel_reason" TEXT;

-- Gap #8: Add admins table (unblocks admin panel auth)
CREATE TABLE "admins" (
    "id" UUID NOT NULL,
    "firebase_uid" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "admins_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "admins_firebase_uid_key" ON "admins"("firebase_uid");
CREATE UNIQUE INDEX "admins_email_key" ON "admins"("email");
