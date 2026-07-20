-- Add veg / non-veg flag to menu items (defaults to veg).
ALTER TABLE "menu_items" ADD COLUMN "is_veg" BOOLEAN NOT NULL DEFAULT true;
