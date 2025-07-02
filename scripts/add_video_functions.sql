-- Fonction pour incrémenter les likes d'une vidéo
CREATE OR REPLACE FUNCTION increment_video_likes(video_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE videos 
  SET likes = COALESCE(likes, 0) + 1,
      updated_at = NOW()
  WHERE id = video_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour décrémenter les likes d'une vidéo
CREATE OR REPLACE FUNCTION decrement_video_likes(video_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE videos 
  SET likes = GREATEST(COALESCE(likes, 0) - 1, 0),
      updated_at = NOW()
  WHERE id = video_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour incrémenter les vues d'une vidéo
CREATE OR REPLACE FUNCTION increment_video_views(video_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE videos 
  SET views = COALESCE(views, 0) + 1,
      updated_at = NOW()
  WHERE id = video_id;
END;
$$ LANGUAGE plpgsql;

-- Créer la table video_likes si elle n'existe pas
CREATE TABLE IF NOT EXISTS video_likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  video_id UUID NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(video_id, user_id)
);

-- Index pour optimiser les requêtes
CREATE INDEX IF NOT EXISTS idx_video_likes_video_id ON video_likes(video_id);
CREATE INDEX IF NOT EXISTS idx_video_likes_user_id ON video_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_video_likes_created_at ON video_likes(created_at);

-- RLS pour video_likes
ALTER TABLE video_likes ENABLE ROW LEVEL SECURITY;

-- Politique pour permettre aux utilisateurs de voir leurs propres likes
CREATE POLICY "Users can view their own likes" ON video_likes
  FOR SELECT USING (auth.uid() = user_id);

-- Politique pour permettre aux utilisateurs d'ajouter leurs propres likes
CREATE POLICY "Users can insert their own likes" ON video_likes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Politique pour permettre aux utilisateurs de supprimer leurs propres likes
CREATE POLICY "Users can delete their own likes" ON video_likes
  FOR DELETE USING (auth.uid() = user_id);

-- Ajouter les colonnes likes et views à la table videos si elles n'existent pas
ALTER TABLE videos 
ADD COLUMN IF NOT EXISTS likes INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS views INTEGER DEFAULT 0;

-- Index pour optimiser les requêtes de tri
CREATE INDEX IF NOT EXISTS idx_videos_likes ON videos(likes DESC);
CREATE INDEX IF NOT EXISTS idx_videos_views ON videos(views DESC);
CREATE INDEX IF NOT EXISTS idx_videos_created_at ON videos(created_at DESC);
