-- Enable trigram matching for typo-tolerant search.
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- GIN trigram index for fuzzy search on kitchen name.
CREATE INDEX "kitchens_kitchen_name_idx" ON "kitchens" USING GIN ("kitchen_name" gin_trgm_ops);

-- GIN trigram index for fuzzy search on dish name.
CREATE INDEX "menu_items_name_idx" ON "menu_items" USING GIN ("name" gin_trgm_ops);
