-- ============================================================
-- Color Tarot Healing App — multi-app member/enrollment model
-- ozma plans to run several apps (one per class) off this same
-- Supabase project. This restructures membership so the shared
-- tables stay the same across every app, while each app has its
-- own student roster, subscription status, and usage tracking.
-- Run this AFTER schema_migration.sql, once, in Supabase SQL Editor.
-- ============================================================

-- 1) Registry of ozma's apps. Add a row here for each new app/class.
create table if not exists public.apps (
  key text primary key,        -- e.g. 'color-tarot', 'oshozen-tarot'
  name text not null,
  created_at timestamptz not null default now()
);

insert into public.apps (key, name) values
  ('color-tarot', '컬러 타로 힐링')
on conflict (key) do nothing;

-- 2) Per-app enrollment. Role / subscription / daily usage now live here,
--    scoped to (member, app), instead of globally on members. The same
--    person can be 'student' in one app and 'general' in another.
create table if not exists public.enrollments (
  id bigserial primary key,
  member_id uuid not null references public.members(id) on delete cascade,
  app_key text not null references public.apps(key),
  role text not null default 'general' check (role in ('general','student')),
  subscription_status text not null default 'free' check (subscription_status in ('free','active','expired')),
  subscription_expires_at timestamptz,
  daily_reading_count int not null default 0,
  daily_reading_reset_date date not null default current_date,
  created_at timestamptz not null default now(),
  unique (member_id, app_key)
);

alter table public.enrollments enable row level security;

drop policy if exists "members can view own enrollments" on public.enrollments;
create policy "members can view own enrollments" on public.enrollments
  for select using (auth.uid() = member_id);
drop policy if exists "members can insert own enrollments" on public.enrollments;
create policy "members can insert own enrollments" on public.enrollments
  for insert with check (auth.uid() = member_id);
drop policy if exists "members can update own enrollments" on public.enrollments;
create policy "members can update own enrollments" on public.enrollments
  for update using (auth.uid() = member_id);

-- Carry over any existing per-member role/subscription data (from the
-- earlier single-app schema) into a 'color-tarot' enrollment row, then
-- drop those columns from members since they now live on enrollments.
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='members' and column_name='role') then
    insert into public.enrollments (member_id, app_key, role, subscription_status, subscription_expires_at, daily_reading_count, daily_reading_reset_date)
    select id, 'color-tarot', role, subscription_status, subscription_expires_at, daily_reading_count, daily_reading_reset_date
    from public.members
    on conflict (member_id, app_key) do nothing;

    alter table public.members
      drop column if exists role,
      drop column if exists subscription_status,
      drop column if exists subscription_expires_at,
      drop column if exists daily_reading_count,
      drop column if exists daily_reading_reset_date;
  end if;
end $$;

-- 3) Per-app student roster (free unlimited access allowlist). Same table
--    shape for every app — just insert rows with the right app_key.
--    e.g. insert into student_emails (email, app_key) values ('a@b.com','color-tarot');
create table if not exists public.student_emails (
  email text not null,
  app_key text not null references public.apps(key),
  note text,
  created_at timestamptz not null default now(),
  primary key (email, app_key)
);
alter table public.student_emails enable row level security;
-- No client policies: this roster is only ever edited via the Supabase
-- SQL Editor / Table Editor, never from inside an app.

-- 4) Auto-assign role when an enrollment is created, from that app's roster.
create or replace function public.assign_role_from_allowlist()
returns trigger
language plpgsql
security definer
as $$
declare
  v_email text;
begin
  select email into v_email from public.members where id = new.member_id;
  if v_email is not null and exists (
    select 1 from public.student_emails se
    where lower(se.email) = lower(v_email) and se.app_key = new.app_key
  ) then
    new.role := 'student';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_assign_role_from_allowlist on public.enrollments;
create trigger trg_assign_role_from_allowlist
  before insert on public.enrollments
  for each row execute function public.assign_role_from_allowlist();

-- 5) Re-check callable by a logged-in client for one app's enrollment
--    (e.g. their email was added to that app's roster after they first
--    signed up). The app calls this on every login.
create or replace function public.recheck_student_status(p_app_key text)
returns boolean
language plpgsql
security definer
as $$
declare
  v_is_student boolean;
begin
  select exists(
    select 1 from public.student_emails se
    join public.members m on lower(m.email) = lower(se.email)
    where m.id = auth.uid() and se.app_key = p_app_key
  ) into v_is_student;

  if v_is_student then
    update public.enrollments set role = 'student'
    where member_id = auth.uid() and app_key = p_app_key;
  end if;

  return v_is_student;
end;
$$;

-- 6) student_codes (manual fallback verification, e.g. a student signs up
--    with a different email than the one on the roster) — scope to app.
alter table public.student_codes
  add column if not exists app_key text not null default 'color-tarot' references public.apps(key);

create or replace function public.verify_student_code(p_code text, p_app_key text default 'color-tarot')
returns boolean
language plpgsql
security definer
as $$
declare
  v_row public.student_codes%rowtype;
begin
  select * into v_row from public.student_codes
    where code = p_code and used = false and app_key = p_app_key;
  if not found then
    return false;
  end if;
  update public.student_codes set used = true, used_by = auth.uid() where code = p_code;
  update public.enrollments set role = 'student' where member_id = auth.uid() and app_key = p_app_key;
  return true;
end;
$$;

-- 7) readings: tag which app each reading came from, for when this
--    project hosts more than one app's history side by side.
alter table public.readings
  add column if not exists app_key text not null default 'color-tarot' references public.apps(key);

-- 8) Manual approval requests — for students without a code. They submit
--    their name (and an optional note, e.g. "8월 정규반"); ozma reviews
--    pending requests in Table Editor and flips status to 'approved',
--    which a trigger turns straight into a 'student' enrollment.
create table if not exists public.verification_requests (
  id bigserial primary key,
  member_id uuid not null references public.members(id) on delete cascade,
  app_key text not null references public.apps(key),
  name text not null,
  note text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  unique (member_id, app_key)
);

alter table public.verification_requests enable row level security;

drop policy if exists "members can view own requests" on public.verification_requests;
create policy "members can view own requests" on public.verification_requests
  for select using (auth.uid() = member_id);
drop policy if exists "members can insert own requests" on public.verification_requests;
create policy "members can insert own requests" on public.verification_requests
  for insert with check (auth.uid() = member_id);
-- No client update/delete policy: only ozma (via Table Editor) reviews requests.

create or replace function public.apply_verification_approval()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.status = 'approved' and old.status is distinct from 'approved' then
    insert into public.enrollments (member_id, app_key, role)
    values (new.member_id, new.app_key, 'student')
    on conflict (member_id, app_key) do update set role = 'student';
    new.reviewed_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_apply_verification_approval on public.verification_requests;
create trigger trg_apply_verification_approval
  before update on public.verification_requests
  for each row execute function public.apply_verification_approval();
