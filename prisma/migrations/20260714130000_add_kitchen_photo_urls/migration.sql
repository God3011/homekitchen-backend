-- Add gallery of kitchen photo URLs to kitchens (self photo already covered by cook_photo_url).
ALTER TABLE "kitchens" ADD COLUMN IF NOT EXISTS "kitchen_photo_urls" TEXT[] NOT NULL DEFAULT '{}';
