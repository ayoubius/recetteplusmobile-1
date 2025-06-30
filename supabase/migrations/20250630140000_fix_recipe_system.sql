-- Migration pour corriger le système de recettes avec la bonne structure JSON

-- Créer la fonction pour incrémenter les vues des recettes
CREATE OR REPLACE FUNCTION increment_recipe_views(recipe_uuid UUID)
RETURNS void AS $$
BEGIN
  UPDATE recipes 
  SET view_count = COALESCE(view_count, 0) + 1,
      updated_at = NOW()
  WHERE id = recipe_uuid;
END;
$$ LANGUAGE plpgsql;

-- Créer la table des favoris si elle n'existe pas
CREATE TABLE IF NOT EXISTS favorites (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  recipe_id UUID REFERENCES recipes(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, recipe_id)
);

-- Créer la table de l'historique utilisateur si elle n'existe pas
CREATE TABLE IF NOT EXISTS user_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  recipe_id UUID REFERENCES recipes(id) ON DELETE CASCADE,
  viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, recipe_id)
);

-- Créer la table des paniers de recettes si elle n'existe pas
CREATE TABLE IF NOT EXISTS recipe_carts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  recipe_id UUID REFERENCES recipes(id) ON DELETE CASCADE,
  recipe_name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Supprimer les données existantes pour éviter les conflits
DELETE FROM products WHERE name IN ('Laitue Romaine', 'Tomates Cerises', 'Concombre', 'Oignons Rouges', 'Fromage Feta');
DELETE FROM recipes WHERE title IN ('Salade Grecque Traditionnelle', 'Pasta Carbonara', 'Tarte aux Pommes');
DELETE FROM videos WHERE title IN ('Comment faire une Salade Grecque', 'Secrets de la Carbonara', 'Tarte aux Pommes Parfaite');

-- Insérer des produits avec de vrais UUIDs
WITH product_inserts AS (
  INSERT INTO products (id, name, price, unit, category, image, in_stock, description, created_at)
  VALUES 
    (gen_random_uuid(), 'Laitue Romaine', 2.50, 'pièce', 'Légumes', 'https://images.unsplash.com/photo-1622206151226-18ca2c9ab4a1?w=400', true, 'Laitue romaine fraîche et croquante', NOW()),
    (gen_random_uuid(), 'Tomates Cerises', 3.20, 'barquette', 'Légumes', 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=400', true, 'Tomates cerises sucrées', NOW()),
    (gen_random_uuid(), 'Concombre', 1.80, 'pièce', 'Légumes', 'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=400', true, 'Concombre frais et croquant', NOW()),
    (gen_random_uuid(), 'Oignons Rouges', 2.10, 'kg', 'Légumes', 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=400', true, 'Oignons rouges doux', NOW()),
    (gen_random_uuid(), 'Fromage Feta', 4.50, 'paquet', 'Fromages', 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=400', true, 'Fromage feta grec authentique', NOW()),
    (gen_random_uuid(), 'Pâtes Spaghetti', 1.20, 'paquet', 'Épicerie', 'https://images.unsplash.com/photo-1551892374-ecf8754cf8b0?w=400', true, 'Spaghetti de qualité premium', NOW()),
    (gen_random_uuid(), 'Lardons', 3.80, 'barquette', 'Charcuterie', 'https://images.unsplash.com/photo-1528607929212-2636ec44253e?w=400', true, 'Lardons fumés', NOW()),
    (gen_random_uuid(), 'Œufs', 2.90, 'boîte', 'Produits frais', 'https://images.unsplash.com/photo-1518569656558-1f25e69d93d7?w=400', true, 'Œufs frais de poules élevées au sol', NOW()),
    (gen_random_uuid(), 'Parmesan', 6.20, 'morceau', 'Fromages', 'https://images.unsplash.com/photo-1452195100486-9cc805987862?w=400', true, 'Parmesan italien AOP', NOW()),
    (gen_random_uuid(), 'Pommes', 2.40, 'kg', 'Fruits', 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=400', true, 'Pommes Golden délicieuses', NOW())
  RETURNING id, name
),
-- Récupérer les IDs des produits insérés
product_ids AS (
  SELECT 
    id,
    name,
    ROW_NUMBER() OVER (ORDER BY name) as rn
  FROM product_inserts
)
-- Insérer les recettes avec les bons IDs de produits
INSERT INTO recipes (id, title, description, image, category, difficulty, prep_time, cook_time, servings, rating, view_count, ingredients, instructions, created_at)
SELECT 
  gen_random_uuid(),
  'Salade Grecque Traditionnelle',
  'Une délicieuse salade grecque avec des légumes frais et de la feta',
  'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600',
  'Entrées',
  'Facile',
  15,
  0,
  4,
  4.5,
  127,
  jsonb_build_array(
    jsonb_build_object('unit', 'pièce', 'quantity', '1', 'productId', (SELECT id FROM product_ids WHERE name = 'Laitue Romaine')),
    jsonb_build_object('unit', 'barquette', 'quantity', '1', 'productId', (SELECT id FROM product_ids WHERE name = 'Tomates Cerises')),
    jsonb_build_object('unit', 'pièce', 'quantity', '1', 'productId', (SELECT id FROM product_ids WHERE name = 'Concombre')),
    jsonb_build_object('unit', 'g', 'quantity', '100', 'productId', (SELECT id FROM product_ids WHERE name = 'Oignons Rouges')),
    jsonb_build_object('unit', 'g', 'quantity', '150', 'productId', (SELECT id FROM product_ids WHERE name = 'Fromage Feta'))
  ),
  ARRAY[
    'Laver et couper la laitue romaine en morceaux',
    'Couper les tomates cerises en deux',
    'Éplucher et trancher le concombre',
    'Émincer finement l''oignon rouge',
    'Couper la feta en cubes',
    'Mélanger tous les ingrédients dans un saladier',
    'Assaisonner avec de l''huile d''olive, du vinaigre et des herbes'
  ],
  NOW()
UNION ALL
SELECT 
  gen_random_uuid(),
  'Pasta Carbonara',
  'La vraie recette italienne de la carbonara avec œufs et parmesan',
  'https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5?w=600',
  'Plats principaux',
  'Moyen',
  10,
  15,
  4,
  4.8,
  89,
  jsonb_build_array(
    jsonb_build_object('unit', 'g', 'quantity', '400', 'productId', (SELECT id FROM product_ids WHERE name = 'Pâtes Spaghetti')),
    jsonb_build_object('unit', 'g', 'quantity', '150', 'productId', (SELECT id FROM product_ids WHERE name = 'Lardons')),
    jsonb_build_object('unit', 'pièces', 'quantity', '3', 'productId', (SELECT id FROM product_ids WHERE name = 'Œufs')),
    jsonb_build_object('unit', 'g', 'quantity', '100', 'productId', (SELECT id FROM product_ids WHERE name = 'Parmesan'))
  ),
  ARRAY[
    'Faire bouillir une grande casserole d''eau salée',
    'Cuire les spaghetti selon les instructions du paquet',
    'Faire revenir les lardons dans une poêle',
    'Battre les œufs avec le parmesan râpé',
    'Égoutter les pâtes en gardant un peu d''eau de cuisson',
    'Mélanger rapidement les pâtes chaudes avec les œufs et le fromage',
    'Ajouter les lardons et servir immédiatement'
  ],
  NOW()
UNION ALL
SELECT 
  gen_random_uuid(),
  'Tarte aux Pommes',
  'Tarte aux pommes classique avec pâte brisée maison',
  'https://images.unsplash.com/photo-1621303837174-89787a7d4729?w=600',
  'Desserts',
  'Moyen',
  30,
  45,
  6,
  4.3,
  156,
  jsonb_build_array(
    jsonb_build_object('unit', 'kg', 'quantity', '1', 'productId', (SELECT id FROM product_ids WHERE name = 'Pommes'))
  ),
  ARRAY[
    'Préparer la pâte brisée et la laisser reposer',
    'Éplucher et couper les pommes en lamelles',
    'Étaler la pâte dans un moule à tarte',
    'Disposer les pommes en rosace sur la pâte',
    'Saupoudrer de sucre et de cannelle',
    'Cuire au four à 180°C pendant 45 minutes',
    'Laisser refroidir avant de servir'
  ],
  NOW();

-- Insérer des vidéos liées aux recettes
WITH recipe_data AS (
  SELECT id, title FROM recipes WHERE title IN ('Salade Grecque Traditionnelle', 'Pasta Carbonara', 'Tarte aux Pommes')
)
INSERT INTO videos (id, title, description, video_url, thumbnail_url, duration, category, view_count, recipe_id, created_at)
SELECT 
  gen_random_uuid(),
  'Comment faire une Salade Grecque',
  'Apprenez à préparer une authentique salade grecque étape par étape',
  'https://example.com/video1.mp4',
  'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400',
  '8:30',
  'Tutoriels',
  1250,
  (SELECT id FROM recipe_data WHERE title = 'Salade Grecque Traditionnelle'),
  NOW()
UNION ALL
SELECT 
  gen_random_uuid(),
  'Secrets de la Carbonara',
  'Les secrets pour réussir une carbonara parfaite comme en Italie',
  'https://example.com/video2.mp4',
  'https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5?w=400',
  '12:15',
  'Tutoriels',
  2100,
  (SELECT id FROM recipe_data WHERE title = 'Pasta Carbonara'),
  NOW()
UNION ALL
SELECT 
  gen_random_uuid(),
  'Tarte aux Pommes Parfaite',
  'Découvrez comment réaliser une tarte aux pommes avec une pâte croustillante',
  'https://example.com/video3.mp4',
  'https://images.unsplash.com/photo-1621303837174-89787a7d4729?w=400',
  '15:45',
  'Tutoriels',
  890,
  (SELECT id FROM recipe_data WHERE title = 'Tarte aux Pommes'),
  NOW();

-- Activer RLS sur les nouvelles tables
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_carts ENABLE ROW LEVEL SECURITY;

-- Politiques RLS pour les favoris
CREATE POLICY "Users can view their own favorites" ON favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own favorites" ON favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own favorites" ON favorites
  FOR DELETE USING (auth.uid() = user_id);

-- Politiques RLS pour l'historique
CREATE POLICY "Users can view their own history" ON user_history
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own history" ON user_history
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own history" ON user_history
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own history" ON user_history
  FOR DELETE USING (auth.uid() = user_id);

-- Politiques RLS pour les paniers de recettes
CREATE POLICY "Users can view their own recipe carts" ON recipe_carts
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own recipe carts" ON recipe_carts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own recipe carts" ON recipe_carts
  FOR DELETE USING (auth.uid() = user_id);

-- Créer des index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_recipe_id ON favorites(recipe_id);
CREATE INDEX IF NOT EXISTS idx_user_history_user_id ON user_history(user_id);
CREATE INDEX IF NOT EXISTS idx_user_history_viewed_at ON user_history(viewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_recipe_carts_user_id ON recipe_carts(user_id);
CREATE INDEX IF NOT EXISTS idx_recipes_category ON recipes(category);
CREATE INDEX IF NOT EXISTS idx_recipes_rating ON recipes(rating DESC);
CREATE INDEX IF NOT EXISTS idx_videos_recipe_id ON videos(recipe_id);

-- Fonction pour nettoyer l'historique ancien (garder seulement les 50 dernières entrées par utilisateur)
CREATE OR REPLACE FUNCTION cleanup_user_history()
RETURNS void AS $$
BEGIN
  DELETE FROM user_history 
  WHERE id NOT IN (
    SELECT id FROM (
      SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY viewed_at DESC) as rn
      FROM user_history
    ) ranked
    WHERE rn <= 50
  );
END;
$$ LANGUAGE plpgsql;

-- Créer une tâche cron pour nettoyer l'historique (si pg_cron est disponible)
-- SELECT cron.schedule('cleanup-history', '0 2 * * *', 'SELECT cleanup_user_history();');
