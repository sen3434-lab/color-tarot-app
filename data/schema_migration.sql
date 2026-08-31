-- ============================================================
-- Color Tarot Healing App — schema additions
-- Existing table `tarot_cards` is NOT modified except adding columns.
-- Run this once in Supabase SQL Editor (or via a direct pg connection).
-- ============================================================

-- 1) Extend tarot_cards with aroma / tea / mood-quote / student-tip fields
alter table public.tarot_cards
  add column if not exists mood_quote text,
  add column if not exists aroma_name text,
  add column if not exists aroma_name_en text,
  add column if not exists aroma_reason text,
  add column if not exists aroma_tip text,
  add column if not exists tea_name text,
  add column if not exists tea_reason text,
  add column if not exists tea_tip text,
  add column if not exists student_question text,
  add column if not exists student_phrase text;

-- 2) Member profiles (1:1 with Supabase Auth users)
create table if not exists public.members (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'general' check (role in ('general','student')),
  subscription_status text not null default 'free' check (subscription_status in ('free','active','expired')),
  subscription_expires_at timestamptz,
  daily_reading_count int not null default 0,
  daily_reading_reset_date date not null default current_date,
  created_at timestamptz not null default now()
);

alter table public.members enable row level security;

create policy "members can view own row" on public.members
  for select using (auth.uid() = id);
create policy "members can update own row" on public.members
  for update using (auth.uid() = id);
create policy "members can insert own row" on public.members
  for insert with check (auth.uid() = id);

-- 3) Pre-registered student verification codes
create table if not exists public.student_codes (
  code text primary key,
  email text,
  used boolean not null default false,
  used_by uuid references public.members(id),
  created_at timestamptz not null default now()
);

alter table public.student_codes enable row level security;
-- No public select policy: codes are checked via the RPC function below,
-- never fetched directly by the client.

create or replace function public.verify_student_code(p_code text)
returns boolean
language plpgsql
security definer
as $$
declare
  v_row public.student_codes%rowtype;
begin
  select * into v_row from public.student_codes where code = p_code and used = false;
  if not found then
    return false;
  end if;
  update public.student_codes set used = true, used_by = auth.uid() where code = p_code;
  update public.members set role = 'student' where id = auth.uid();
  return true;
end;
$$;

-- 4) Reading history (mood calendar / archive)
create table if not exists public.readings (
  id bigserial primary key,
  user_id uuid not null references public.members(id) on delete cascade,
  card_id bigint not null references public.tarot_cards(id),
  mood_input text,
  memo text,
  created_at timestamptz not null default now()
);

alter table public.readings enable row level security;

create policy "users can view own readings" on public.readings
  for select using (auth.uid() = user_id);
create policy "users can insert own readings" on public.readings
  for insert with check (auth.uid() = user_id);
create policy "users can delete own readings" on public.readings
  for delete using (auth.uid() = user_id);

-- 5) tarot_cards: ensure public read access (should already exist, safe to re-run)
alter table public.tarot_cards enable row level security;
drop policy if exists "public can read tarot_cards" on public.tarot_cards;
create policy "public can read tarot_cards" on public.tarot_cards
  for select using (true);
