// Structure complète de la base de données basée sur db.json
export interface DatabaseSchema {
  // Tables principales
  videos: VideoTable
  recipes: RecipeTable
  products: ProductTable
  profiles: ProfileTable
  orders: OrderTable
  favorites: FavoriteTable
  cart_items: CartItemTable
  // Tables de gestion
  admin_permissions: AdminPermissionTable
  delivery_zones: DeliveryZoneTable
  delivery_tracking: DeliveryTrackingTable
  // Tables de panier
  preconfigured_carts: PreconfiguredCartTable
  user_carts: UserCartTable
  recipe_carts: RecipeCartTable
  personal_carts: PersonalCartTable
  // Tables de catégories
  product_categories: ProductCategoryTable
  recipe_categories: RecipeCategoryTable
  manageable_product_categories: ManageableProductCategoryTable
  manageable_recipe_categories: ManageableRecipeCategoryTable
  // Tables utilitaires
  user_locations: UserLocationTable
  user_history: UserHistoryTable
  video_likes: VideoLikeTable
  newsletter_campaigns: NewsletterCampaignTable
  team_members: TeamMemberTable
}

// Définitions des tables principales
interface VideoTable {
  id: string // uuid, primary key
  title: string // text, required
  description?: string // text, optional
  video_url?: string // text, optional
  thumbnail?: string // text, optional
  duration?: string // text, optional
  category: string // text, required
  views: number // integer, default 0
  likes: number // integer, default 0
  recipe_id?: string // uuid, foreign key to recipes
  created_by?: string // uuid, foreign key to profiles
  created_at: string // timestamp with time zone
  updated_at?: string // timestamp with time zone
}

interface RecipeTable {
  id: string // uuid, primary key
  title: string // text, required
  description?: string // text, optional
  image?: string // text, optional
  category: string // text, required
  difficulty?: string // text, optional
  cook_time: number // integer, required (minutes)
  prep_time?: number // integer, optional (minutes)
  servings: number // integer, required
  rating: number // numeric, default 0
  view_count: number // integer, default 0
  ingredients: any // jsonb, required
  instructions: string[] // array of text, required
  video_id?: string // uuid, foreign key to videos
  created_by?: string // uuid, foreign key to profiles
  created_at: string // timestamp with time zone
}

interface ProductTable {
  id: string // uuid, primary key
  name: string // text, required
  image?: string // text, optional
  price: number // numeric, required
  unit: string // text, required (kg, pièce, etc.)
  category: string // text, required
  rating: number // numeric, default 0
  in_stock: boolean // boolean, default true
  promotion?: any // jsonb, optional
  created_at: string // timestamp with time zone
}

interface ProfileTable {
  id: string // uuid, primary key (from auth.users)
  email?: string // text, optional
  display_name?: string // text, optional
  photo_url?: string // text, optional
  phone_number?: string // text, optional
  bio?: string // text, optional
  location?: string // text, optional
  date_of_birth?: string // date, optional
  role: string // text, default 'user'
  preferences: any // jsonb, default settings
  privacy_settings: any // jsonb, default settings
  notification_settings: any // jsonb, default settings
  created_at: string // timestamp with time zone
  updated_at: string // timestamp with time zone
}

interface OrderTable {
  id: string // uuid, primary key
  user_id: string // uuid, foreign key to profiles
  total_amount: number // numeric, required
  delivery_fee?: number // numeric, optional
  items: any // jsonb, required
  delivery_address: any // jsonb, required
  delivery_latitude?: string // text, optional
  delivery_longitude?: string // text, optional
  delivery_zone_id?: string // text, optional
  google_maps_link?: string // text, auto-generated
  qr_code?: string // text, auto-generated
  status: string // text, default 'pending'
  delivery_notes?: string // text, optional
  validated_by?: string // uuid, foreign key to profiles
  validated_at?: string // timestamp, optional
  assigned_to?: string // uuid, foreign key to profiles
  assigned_at?: string // timestamp, optional
  picked_up_at?: string // timestamp, optional
  delivered_at?: string // timestamp, optional
  created_at: string // timestamp with time zone
  updated_at: string // timestamp with time zone
}

// Définitions des tables de gestion
interface AdminPermissionTable {
  id: string // uuid, primary key
  admin_id: string // uuid, foreign key to profiles
  permission_level: string // text, required
  created_at: string // timestamp with time zone
}

interface DeliveryZoneTable {
  id: string // uuid, primary key
  name: string // text, required
  description?: string // text, optional
  boundaries: any // jsonb, required
  created_at: string // timestamp with time zone
}

interface DeliveryTrackingTable {
  id: string // uuid, primary key
  order_id: string // uuid, foreign key to orders
  status: string // text, required
  location?: string // text, optional
  updated_at: string // timestamp with time zone
}

// Définitions des tables de panier
interface PreconfiguredCartTable {
  id: string // uuid, primary key
  name: string // text, required
  items: any // jsonb, required
  created_at: string // timestamp with time zone
}

interface UserCartTable {
  id: string // uuid, primary key
  user_id: string // uuid, foreign key to profiles
  items: any // jsonb, required
  created_at: string // timestamp with time zone
}

interface RecipeCartTable {
  id: string // uuid, primary key
  recipe_id: string // uuid, foreign key to recipes
  items: any // jsonb, required
  created_at: string // timestamp with time zone
}

interface PersonalCartTable {
  id: string // uuid, primary key
  profile_id: string // uuid, foreign key to profiles
  items: any // jsonb, required
  created_at: string // timestamp with time zone
}

// Définitions des tables de catégories
interface ProductCategoryTable {
  id: string // uuid, primary key
  name: string // text, required
  description?: string // text, optional
  created_at: string // timestamp with time zone
}

interface RecipeCategoryTable {
  id: string // uuid, primary key
  name: string // text, required
  description?: string // text, optional
  created_at: string // timestamp with time zone
}

interface ManageableProductCategoryTable {
  id: string // uuid, primary key
  category_id: string // uuid, foreign key to product_categories
  manager_id: string // uuid, foreign key to profiles
  created_at: string // timestamp with time zone
}

interface ManageableRecipeCategoryTable {
  id: string // uuid, primary key
  category_id: string // uuid, foreign key to recipe_categories
  manager_id: string // uuid, foreign key to profiles
  created_at: string // timestamp with time zone
}

// Définitions des tables utilitaires
interface UserLocationTable {
  id: string // uuid, primary key
  profile_id: string // uuid, foreign key to profiles
  location: any // jsonb, required
  created_at: string // timestamp with time zone
}

interface UserHistoryTable {
  id: string // uuid, primary key
  profile_id: string // uuid, foreign key to profiles
  actions: any // jsonb, required
  created_at: string // timestamp with time zone
}

interface VideoLikeTable {
  id: string // uuid, primary key
  video_id: string // uuid, foreign key to videos
  profile_id: string // uuid, foreign key to profiles
  created_at: string // timestamp with time zone
}

interface NewsletterCampaignTable {
  id: string // uuid, primary key
  name: string // text, required
  description?: string // text, optional
  recipients: any // jsonb, required
  created_at: string // timestamp with time zone
}

interface TeamMemberTable {
  id: string // uuid, primary key
  name: string // text, required
  role: string // text, required
  created_at: string // timestamp with time zone
}

// Définitions des tables secondaires
interface FavoriteTable {
  id: string // uuid, primary key
  profile_id: string // uuid, foreign key to profiles
  item_id: string // uuid, required
  item_type: string // text, required (video, recipe, product)
  created_at: string // timestamp with time zone
}

interface CartItemTable {
  id: string // uuid, primary key
  cart_id: string // uuid, foreign key to preconfigured_carts, user_carts, recipe_carts, personal_carts
  product_id: string // uuid, foreign key to products
  quantity: number // integer, required
  created_at: string // timestamp with time zone
}
