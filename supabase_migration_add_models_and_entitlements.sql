-- Models catalog and user entitlements for Free vs Pro

-- Use UUID id; keep a separate slug for OpenRouter mapping
create extension if not exists pgcrypto; -- for gen_random_uuid()

create table if not exists models (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,           -- OpenRouter slug or your alias
  display_name text not null,
  tier text not null check (tier in ('basic','premium')),
  enabled boolean not null default true,
  sort_order int not null default 0,
  input_max_tokens int,               -- optional guardrails
  output_max_tokens int,              -- optional guardrails
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists models_enabled_idx on models (enabled, tier, sort_order);

-- 2) User entitlements (Free/Pro)
create table if not exists user_entitlements (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan text not null check (plan in ('free','pro')),
  status text not null default 'active',   -- 'active' | 'expired' | 'revoked'
  source text default 'apple',             -- 'apple' | 'google' | 'huawei' | 'stripe' | 'manual'
  original_transaction_id text,            -- for store reconciliation
  renews_at timestamptz,
  updated_at timestamptz not null default now()
);

-- Everyone starts Free if you upsert later
insert into user_entitlements (user_id, plan, status)
select id, 'free', 'active' from auth.users
on conflict (user_id) do nothing;

-- Trigger to auto-update updated_at
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists t_models_updated on models;
create trigger t_models_updated
before update on models
for each row execute function set_updated_at();

drop trigger if exists t_user_entitlements_updated on user_entitlements;
create trigger t_user_entitlements_updated
before update on user_entitlements
for each row execute function set_updated_at();

-- Minimal RLS
alter table models enable row level security;
do $$ begin
  if not exists (
    select 1 from pg_policies where tablename = 'models' and policyname = 'public_read_models'
  ) then
    create policy "public_read_models"
      on models for select
      using (enabled = true);
  end if;
end $$;

alter table user_entitlements enable row level security;
do $$ begin
  if not exists (
    select 1 from pg_policies where tablename = 'user_entitlements' and policyname = 'user_read_own_entitlement'
  ) then
    create policy "user_read_own_entitlement"
      on user_entitlements for select
      using (auth.uid() = user_id);
  end if;
end $$;

-- Server roles (edge functions) should be granted insert/update via service key/role
-- Adjust as needed for your environment.

-- Seed at least one Basic model
insert into models (slug, display_name, tier, enabled, sort_order)
values
  ('openai/gpt-4o-mini', 'Basic (GPT-4o mini)', 'basic', true, 1)
on conflict (slug) do update set display_name = excluded.display_name;


