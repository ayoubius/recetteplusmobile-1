-- Analyse de la structure basée sur les migrations existantes

-- 1. TABLE VIDEOS (système vidéo avancé)
-- Colonnes identifiées :
-- - id (UUID, PRIMARY KEY)
-- - title (TEXT)
-- - description (TEXT)
-- - category (TEXT)
-- - duration (INTEGER) -- en secondes
-- - views (INTEGER, DEFAULT 0)
-- - likes (INTEGER, DEFAULT 0)
-- - video_url (TEXT)
-- - thumbnail (TEXT)
-- - created_at (TIMESTAMP)
-- - updated_at (TIMESTAMP)

-- 2. TABLE RECIPES
-- Colonnes identifiées :
-- - id (UUID, PRIMARY KEY)
-- - title (TEXT)
-- - description (TEXT)
-- - image (TEXT)
-- - category (TEXT)
-- - difficulty (TEXT)
-- - prep_time (INTEGER)
-- - cook_time (INTEGER)
-- - servings (INTEGER)
-- - rating (DECIMAL)
-- - view_count (INTEGER)
-- - ingredients (JSONB)
-- - instructions (JSONB/TEXT[])
-- - created_at (TIMESTAMP)
-- - updated_at (TIMESTAMP)

-- 3. TABLE PRODUCTS
-- Colonnes identifiées :
-- - id (UUID, PRIMARY KEY)
-- - name (TEXT)
-- - description (TEXT)
-- - image_url (TEXT)
-- - price (DECIMAL)
-- - unit (TEXT)
-- - category (TEXT)
-- - in_stock (BOOLEAN)
-- - stock_quantity (INTEGER)
-- - is_active (BOOLEAN)
-- - created_at (TIMESTAMP)

-- 4. TABLE USER_PROFILES
-- Colonnes identifiées :
-- - user_id (UUID, PRIMARY KEY)
-- - email (TEXT)
-- - display_name (TEXT)
-- - first_name (TEXT)
-- - last_name (TEXT)
-- - phone_number (TEXT)
-- - photo_url (TEXT)
-- - bio (TEXT)
-- - location (TEXT)
-- - role (TEXT, DEFAULT 'user')
-- - created_at (TIMESTAMP)
-- - updated_at (TIMESTAMP)

-- 5. TABLE FAVORITES
-- Colonnes identifiées :
-- - id (UUID, PRIMARY KEY)
-- - user_id (UUID, FOREIGN KEY)
-- - item_id (UUID) -- peut référencer recipes ou autres
-- - type (TEXT) -- 'recipe', 'video', etc.
-- - recipe_id (UUID, FOREIGN KEY) -- pour compatibilité
-- - created_at (TIMESTAMP)

-- 6. TABLE USER_HISTORY
-- Colonnes identifiées :
-- - id (UUID, PRIMARY KEY)
-- - user_id (UUID, FOREIGN KEY)
-- - recipe_id (UUID, FOREIGN KEY)
-- - viewed_at (TIMESTAMP)

-- 7. TABLE ORDERS (système de livraison)
-- Colonnes identifiées :
-- - id (UUID, PRIMARY KEY)
-- - user_id (UUID, FOREIGN KEY)
-- - total_amount (DECIMAL)
-- - status (TEXT)
-- - items (JSONB)
-- - delivery_address (TEXT)
-- - delivery_zone_id (UUID)
-- - delivery_fee (DECIMAL)
-- - delivery_notes (TEXT)
-- - delivery_person_id (UUID)
-- - estimated_delivery_time (TIMESTAMP)
-- - actual_delivery_time (TIMESTAMP)
-- - qr_code (TEXT)
-- - created_at (TIMESTAMP)
-- - updated_at (TIMESTAMP)

-- 8. TABLES ADDITIONNELLES PROBABLES
-- - cart_items
-- - recipe_carts
-- - delivery_zones
-- - delivery_persons
-- - order_status_history

-- FONCTIONS IDENTIFIÉES
-- - increment_video_views(video_id UUID)
-- - increment_video_likes(video_id UUID)
-- - increment_recipe_views(recipe_uuid UUID)

SELECT 'Structure analysée à partir des migrations et services' as status;
