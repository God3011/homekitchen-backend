-- CreateEnum
CREATE TYPE "FulfillmentType" AS ENUM ('pickup', 'delivery');

-- CreateEnum
CREATE TYPE "OrderStatus" AS ENUM ('received', 'accepted', 'preparing', 'ready', 'customer_en_route', 'customer_arrived', 'out_for_delivery', 'completed', 'rejected', 'cancelled');

-- CreateEnum
CREATE TYPE "KitchenStatus" AS ENUM ('pending_review', 'verified', 'suspended');

-- CreateEnum
CREATE TYPE "PreferenceType" AS ENUM ('less_spicy', 'normal_spicy', 'extra_spicy', 'no_onion', 'no_garlic', 'less_oil', 'extra_rice');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('created', 'authorized', 'captured', 'failed', 'refunded');

-- CreateEnum
CREATE TYPE "DocType" AS ENUM ('fssai', 'id_proof');

-- CreateTable
CREATE TABLE "platform_config" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "platform_fee_paise" INTEGER NOT NULL DEFAULT 500,
    "seller_daily_fee_paise" INTEGER NOT NULL DEFAULT 5000,
    "order_cap_paise" INTEGER NOT NULL DEFAULT 20000,
    "currency" CHAR(3) NOT NULL DEFAULT 'INR',
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "platform_config_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "zones" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "center_lat" DOUBLE PRECISION NOT NULL,
    "center_lng" DOUBLE PRECISION NOT NULL,
    "radius_m" INTEGER NOT NULL DEFAULT 5000,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "zones_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customers" (
    "id" UUID NOT NULL,
    "phone" TEXT NOT NULL,
    "name" TEXT,
    "home_zone_id" UUID,
    "whatsapp_opt_in" BOOLEAN NOT NULL DEFAULT false,
    "signup_method" TEXT NOT NULL DEFAULT 'phone_otp',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "customers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kitchens" (
    "id" UUID NOT NULL,
    "phone" TEXT NOT NULL,
    "kitchen_name" TEXT NOT NULL,
    "cook_name" TEXT,
    "cook_photo_url" TEXT,
    "story" TEXT,
    "signature_dish" TEXT,
    "address_line" TEXT,
    "lat" DOUBLE PRECISION,
    "lng" DOUBLE PRECISION,
    "zone_id" UUID,
    "status" "KitchenStatus" NOT NULL DEFAULT 'pending_review',
    "verified_at" TIMESTAMPTZ,
    "language_pref" TEXT NOT NULL DEFAULT 'en',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "kitchens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kitchen_documents" (
    "id" UUID NOT NULL,
    "kitchen_id" UUID NOT NULL,
    "doc_type" "DocType" NOT NULL,
    "file_url" TEXT NOT NULL,
    "uploaded_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "kitchen_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "kitchen_hours" (
    "id" UUID NOT NULL,
    "kitchen_id" UUID NOT NULL,
    "day_of_week" INTEGER NOT NULL,
    "open_time" TEXT NOT NULL,
    "close_time" TEXT NOT NULL,

    CONSTRAINT "kitchen_hours_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "menu_categories" (
    "id" UUID NOT NULL,
    "kitchen_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "menu_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "menu_items" (
    "id" UUID NOT NULL,
    "kitchen_id" UUID NOT NULL,
    "category_id" UUID,
    "name" TEXT NOT NULL,
    "photo_url" TEXT,
    "price_paise" INTEGER NOT NULL,
    "pickup_available" BOOLEAN NOT NULL DEFAULT true,
    "delivery_available" BOOLEAN NOT NULL DEFAULT false,
    "delivery_fee_paise" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "menu_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "menu_item_preferences" (
    "menu_item_id" UUID NOT NULL,
    "preference" "PreferenceType" NOT NULL,

    CONSTRAINT "menu_item_preferences_pkey" PRIMARY KEY ("menu_item_id","preference")
);

-- CreateTable
CREATE TABLE "kitchen_daily_status" (
    "kitchen_id" UUID NOT NULL,
    "service_date" DATE NOT NULL,
    "is_cooking" BOOLEAN NOT NULL DEFAULT false,
    "fee_charged" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "kitchen_daily_status_pkey" PRIMARY KEY ("kitchen_id","service_date")
);

-- CreateTable
CREATE TABLE "menu_daily_availability" (
    "menu_item_id" UUID NOT NULL,
    "service_date" DATE NOT NULL,
    "plates_total" INTEGER NOT NULL DEFAULT 0,
    "plates_remaining" INTEGER NOT NULL DEFAULT 0,
    "is_available" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "menu_daily_availability_pkey" PRIMARY KEY ("menu_item_id","service_date")
);

-- CreateTable
CREATE TABLE "orders" (
    "id" UUID NOT NULL,
    "customer_id" UUID NOT NULL,
    "kitchen_id" UUID NOT NULL,
    "zone_id" UUID,
    "fulfillment" "FulfillmentType" NOT NULL,
    "status" "OrderStatus" NOT NULL DEFAULT 'received',
    "food_total_paise" INTEGER NOT NULL,
    "platform_fee_paise" INTEGER NOT NULL DEFAULT 500,
    "delivery_fee_paise" INTEGER NOT NULL DEFAULT 0,
    "grand_total_paise" INTEGER NOT NULL,
    "eta_minutes" INTEGER,
    "handover_code" CHAR(4) NOT NULL,
    "placed_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "accepted_at" TIMESTAMPTZ,
    "ready_at" TIMESTAMPTZ,
    "completed_at" TIMESTAMPTZ,
    "reject_reason" TEXT,

    CONSTRAINT "orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_items" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "menu_item_id" UUID NOT NULL,
    "item_name" TEXT NOT NULL,
    "unit_price_paise" INTEGER NOT NULL,
    "quantity" INTEGER NOT NULL,

    CONSTRAINT "order_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_item_preferences" (
    "order_item_id" UUID NOT NULL,
    "preference" "PreferenceType" NOT NULL,

    CONSTRAINT "order_item_preferences_pkey" PRIMARY KEY ("order_item_id","preference")
);

-- CreateTable
CREATE TABLE "order_status_history" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "status" "OrderStatus" NOT NULL,
    "changed_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "order_status_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payments" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "amount_paise" INTEGER NOT NULL,
    "method" TEXT,
    "status" "PaymentStatus" NOT NULL DEFAULT 'created',
    "razorpay_order_id" TEXT,
    "razorpay_payment_id" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ratings" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "customer_id" UUID NOT NULL,
    "kitchen_id" UUID NOT NULL,
    "stars" INTEGER NOT NULL,
    "comment" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ratings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payouts" (
    "id" UUID NOT NULL,
    "kitchen_id" UUID NOT NULL,
    "amount_paise" INTEGER NOT NULL,
    "payout_date" DATE NOT NULL,
    "note" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payouts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "favorites" (
    "customer_id" UUID NOT NULL,
    "kitchen_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "favorites_pkey" PRIMARY KEY ("customer_id","kitchen_id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL,
    "actor_type" TEXT NOT NULL,
    "actor_id" TEXT,
    "action" TEXT NOT NULL,
    "entity_type" TEXT,
    "entity_id" TEXT,
    "metadata" JSONB,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "customers_phone_key" ON "customers"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "kitchens_phone_key" ON "kitchens"("phone");

-- CreateIndex
CREATE INDEX "kitchens_zone_id_status_idx" ON "kitchens"("zone_id", "status");

-- CreateIndex
CREATE INDEX "menu_items_kitchen_id_is_active_idx" ON "menu_items"("kitchen_id", "is_active");

-- CreateIndex
CREATE INDEX "orders_kitchen_id_status_idx" ON "orders"("kitchen_id", "status");

-- CreateIndex
CREATE INDEX "orders_customer_id_placed_at_idx" ON "orders"("customer_id", "placed_at");

-- CreateIndex
CREATE INDEX "order_items_order_id_idx" ON "order_items"("order_id");

-- CreateIndex
CREATE INDEX "order_status_history_order_id_changed_at_idx" ON "order_status_history"("order_id", "changed_at");

-- CreateIndex
CREATE UNIQUE INDEX "payments_order_id_key" ON "payments"("order_id");

-- CreateIndex
CREATE UNIQUE INDEX "ratings_order_id_key" ON "ratings"("order_id");

-- CreateIndex
CREATE INDEX "ratings_kitchen_id_idx" ON "ratings"("kitchen_id");

-- CreateIndex
CREATE INDEX "payouts_kitchen_id_payout_date_idx" ON "payouts"("kitchen_id", "payout_date");

-- CreateIndex
CREATE INDEX "audit_logs_entity_type_entity_id_idx" ON "audit_logs"("entity_type", "entity_id");

-- AddForeignKey
ALTER TABLE "customers" ADD CONSTRAINT "customers_home_zone_id_fkey" FOREIGN KEY ("home_zone_id") REFERENCES "zones"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kitchens" ADD CONSTRAINT "kitchens_zone_id_fkey" FOREIGN KEY ("zone_id") REFERENCES "zones"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kitchen_documents" ADD CONSTRAINT "kitchen_documents_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "kitchens"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kitchen_hours" ADD CONSTRAINT "kitchen_hours_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "kitchens"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "menu_categories" ADD CONSTRAINT "menu_categories_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "kitchens"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "menu_items" ADD CONSTRAINT "menu_items_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "kitchens"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "menu_items" ADD CONSTRAINT "menu_items_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "menu_categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "menu_item_preferences" ADD CONSTRAINT "menu_item_preferences_menu_item_id_fkey" FOREIGN KEY ("menu_item_id") REFERENCES "menu_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "kitchen_daily_status" ADD CONSTRAINT "kitchen_daily_status_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "kitchens"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "menu_daily_availability" ADD CONSTRAINT "menu_daily_availability_menu_item_id_fkey" FOREIGN KEY ("menu_item_id") REFERENCES "menu_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "kitchens"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_zone_id_fkey" FOREIGN KEY ("zone_id") REFERENCES "zones"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_menu_item_id_fkey" FOREIGN KEY ("menu_item_id") REFERENCES "menu_items"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_item_preferences" ADD CONSTRAINT "order_item_preferences_order_item_id_fkey" FOREIGN KEY ("order_item_id") REFERENCES "order_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_status_history" ADD CONSTRAINT "order_status_history_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ratings" ADD CONSTRAINT "ratings_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ratings" ADD CONSTRAINT "ratings_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ratings" ADD CONSTRAINT "ratings_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "kitchens"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payouts" ADD CONSTRAINT "payouts_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "kitchens"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "favorites" ADD CONSTRAINT "favorites_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "favorites" ADD CONSTRAINT "favorites_kitchen_id_fkey" FOREIGN KEY ("kitchen_id") REFERENCES "kitchens"("id") ON DELETE CASCADE ON UPDATE CASCADE;
