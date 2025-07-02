-- Fonction pour incrémenter les likes d'une vidéo
CREATE OR REPLACE FUNCTION increment_video_likes(video_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE videos 
  SET likes = likes + 1 
  WHERE id = video_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour décrémenter les likes d'une vidéo
CREATE OR REPLACE FUNCTION decrement_video_likes(video_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE videos 
  SET likes = GREATEST(likes - 1, 0)
  WHERE id = video_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour incrémenter les vues d'une vidéo
CREATE OR REPLACE FUNCTION increment_video_views(video_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE videos 
  SET views = views + 1 
  WHERE id = video_id;
END;
$$ LANGUAGE plpgsql;
