-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.app_config (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  key text NOT NULL UNIQUE,
  value text NOT NULL,
  description text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT app_config_pkey PRIMARY KEY (id)
);
CREATE TABLE public.app_version_control (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  platform text NOT NULL UNIQUE CHECK (platform = ANY (ARRAY['ios'::text, 'android'::text, 'web'::text, 'all'::text])),
  minimum_version text NOT NULL,
  minimum_build_number integer NOT NULL,
  latest_version text NOT NULL,
  latest_build_number integer NOT NULL,
  force_update boolean DEFAULT false,
  show_update_prompt boolean DEFAULT true,
  update_message text,
  update_title text DEFAULT 'Update Available'::text,
  ios_app_store_url text,
  android_play_store_url text,
  web_app_url text,
  maintenance_mode boolean DEFAULT false,
  maintenance_message text DEFAULT 'App is currently under maintenance. Please check back later.'::text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT app_version_control_pkey PRIMARY KEY (id)
);
CREATE TABLE public.chats (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  name text NOT NULL,
  short_description text NOT NULL,
  last_message text,
  last_message_time timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  is_pinned boolean DEFAULT false,
  sort_order integer DEFAULT 0,
  avatar_url text,
  response_tone text DEFAULT 'friendly'::text,
  response_length text DEFAULT 'balanced'::text,
  writing_style text DEFAULT 'simple'::text,
  use_emojis boolean DEFAULT false,
  system_prompt text NOT NULL DEFAULT 'You are a helpful AI assistant.'::text,
  last_read_at timestamp with time zone,
  model text,
  CONSTRAINT chats_pkey PRIMARY KEY (id),
  CONSTRAINT chats_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  chat_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role text NOT NULL CHECK (role = ANY (ARRAY['user'::text, 'assistant'::text, 'system'::text])),
  content text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  is_pending boolean DEFAULT false,
  has_error boolean DEFAULT false,
  image_urls ARRAY,
  generated_images ARRAY,
  model text,
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT messages_chat_id_fkey FOREIGN KEY (chat_id) REFERENCES public.chats(id),
  CONSTRAINT messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.models (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  model_id text NOT NULL UNIQUE,
  provider text NOT NULL DEFAULT 'openrouter'::text,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT models_pkey PRIMARY KEY (id)
);
CREATE TABLE public.notes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT notes_pkey PRIMARY KEY (id),
  CONSTRAINT notes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_entitlements (
  user_id uuid NOT NULL,
  plan text NOT NULL CHECK (plan = ANY (ARRAY['free'::text, 'pro'::text])),
  status text NOT NULL DEFAULT 'active'::text,
  source text DEFAULT 'apple'::text,
  original_transaction_id text,
  renews_at timestamp with time zone,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_entitlements_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_entitlements_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_profiles (
  id uuid NOT NULL,
  avatar_url text,
  display_name text,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  onboarding_completed boolean DEFAULT false,
  preferences ARRAY DEFAULT '{}'::text[],
  date_of_birth date,
  preferred_language character varying DEFAULT 'en'::character varying,
  experience_level character varying,
  use_context character varying,
  last_app_activity timestamp with time zone,
  re_engagement_enabled boolean DEFAULT true,
  last_re_engagement_sent timestamp with time zone,
  CONSTRAINT user_profiles_pkey PRIMARY KEY (id),
  CONSTRAINT user_profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);