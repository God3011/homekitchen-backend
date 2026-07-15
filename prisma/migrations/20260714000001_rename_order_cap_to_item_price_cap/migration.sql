-- AlterTable: rename order_cap_paise → item_price_cap_paise, add low_stock_threshold
ALTER TABLE "platform_config" RENAME COLUMN "order_cap_paise" TO "item_price_cap_paise";
ALTER TABLE "platform_config" ADD COLUMN "low_stock_threshold" INTEGER NOT NULL DEFAULT 3;
