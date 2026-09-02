-- ============================================================
-- Color Tarot Healing App — display name
-- Lets the app greet members by name ("OO님") instead of staying
-- anonymous. Filled from the Google profile name on OAuth signup,
-- or from a nickname the member types in on email/password signup.
-- Run this once in Supabase SQL Editor.
-- ============================================================

alter table public.members
  add column if not exists display_name text;
