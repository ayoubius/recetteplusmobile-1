// Fonctions de base de données identifiées
export interface DatabaseFunctions {
  // Fonctions d'autorisation
  has_admin_permission: (permission_type: string) => boolean
  has_order_validation_permission: () => boolean
  has_delivery_permission: () => boolean
  is_super_admin: () => boolean
  is_admin: () => boolean

  // Fonctions de métriques
  increment_video_views: (video_id: string) => void
  increment_video_likes: (video_id: string) => void
  increment_recipe_views: (recipe_uuid: string) => void

  // Fonctions utilitaires
  generate_google_maps_link: (lat: number, lng: number) => string
  calculate_distance: (lat1: number, lon1: number, lat2: number, lon2: number) => number
  find_nearest_delivery_zone: (lat: number, lng: number) => string

  // Fonctions de gestion des paniers
  get_personal_cart_details: (cart_id: string) => any
  get_recipe_cart_details: (cart_id: string) => any
  get_preconfigured_cart_details: (cart_id: string) => any

  // Fonctions de profil
  update_profile_avatar: (user_id: string, avatar_url: string) => void
  delete_old_avatar: (user_id: string) => void

  // Fonction de gestion des utilisateurs
  handle_new_user: () => any // trigger function
}
