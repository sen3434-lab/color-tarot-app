-- ============================================================
-- OZ 타로 공용 코인 지갑 (모든 OZ 타로 앱이 같은 지갑을 씀)
--
-- 규칙
--   가입 보너스   5코인 (계정당 1회)
--   출석 보너스   1코인 (하루 1회, 한국시간 기준, 모든 앱 합쳐서 1회)
--   수강생 코드   class_codes.coins 만큼 (기본 100, 계정·코드당 1회)
--   코인 충전     결제 서버가 credit_purchase() 로만 지급 (구글 결제)
--   리딩/해설     coin_prices 표의 가격만큼 차감 (가격은 서버 표가 정함)
--
-- 보안 원칙
--   - 잔액·내역·결제 표는 앱(로그인 사용자)이 "읽기"만 가능, 쓰기 불가.
--   - 모든 지급/차감은 security definer 함수만 하며, 그 안에서 로그인한
--     본인(auth.uid())에게만 적용됨. 가격은 클라이언트가 못 정함.
--   - 환불/충전 같은 위험한 함수는 service_role(우리 서버)만 실행 가능.
--   - 잔액은 0 밑으로 내려갈 수 없고(제약), 같은 지급은 중복되지 않음
--     (부분 유니크 인덱스).
--
-- 먼저 security_1_check.sql / security_2_fix_and_audit.sql 을 실행한 뒤,
-- Supabase SQL Editor에서 한 번 실행하세요. 재실행해도 안전합니다.
-- ============================================================

-- ------------------------------------------------------------
-- 1) 표
-- ------------------------------------------------------------
create table if not exists public.wallets (
  member_id uuid primary key references public.members(id) on delete cascade,
  balance int not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.coin_ledger (
  id bigserial primary key,
  member_id uuid not null references public.members(id) on delete cascade,
  delta int not null check (delta <> 0),
  balance_after int not null check (balance_after >= 0),
  kind text not null check (kind in
    ('signup_bonus','daily_attendance','class_code','purchase','spend','refund','adjust','admin_grant')),
  app_key text references public.apps(key),
  ref text,                -- 리딩 id / 프로필 id / 코드 / 결제 id
  memo text,               -- 화면에 보여줄 설명
  grant_date date,         -- 출석 보너스의 한국시간 날짜
  granted_by uuid references public.members(id) on delete set null,  -- 운영자 지급일 때 누가
  created_at timestamptz not null default now()
);

-- (표가 이미 있던 경우를 위해: 새 칸과 종류 규칙을 보강)
alter table public.coin_ledger add column if not exists granted_by uuid references public.members(id) on delete set null;
alter table public.coin_ledger drop constraint if exists coin_ledger_kind_check;
alter table public.coin_ledger add constraint coin_ledger_kind_check check (kind in
  ('signup_bonus','daily_attendance','class_code','purchase','spend','refund','adjust','admin_grant'));

-- 중복 지급 방지
create unique index if not exists coin_ledger_signup_once
  on public.coin_ledger (member_id) where kind = 'signup_bonus';
create unique index if not exists coin_ledger_attendance_once
  on public.coin_ledger (member_id, grant_date) where kind = 'daily_attendance';
create unique index if not exists coin_ledger_class_code_once
  on public.coin_ledger (member_id, ref) where kind = 'class_code';
create unique index if not exists coin_ledger_purchase_once
  on public.coin_ledger (ref) where kind = 'purchase';
-- 같은 운영자 지급 묶음(batch)이 두 번 들어가지 않게 (화면에서 두 번 눌러도 안전)
create unique index if not exists coin_ledger_admin_grant_once
  on public.coin_ledger (member_id, ref) where kind = 'admin_grant';
create index if not exists coin_ledger_member_recent
  on public.coin_ledger (member_id, created_at desc);

-- 운영자 목록. 앱에서는 읽을 수도 쓸 수도 없고, SQL Editor 에서만 추가/삭제.
create table if not exists public.admins (
  member_id uuid primary key references public.members(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- 아직 가입하지 않은 수강생을 위한 "가입하면 자동 지급" 대기 목록
create table if not exists public.coin_pending_grants (
  id bigserial primary key,
  email text not null check (email = lower(email)),
  coins int not null check (coins between 1 and 5000),
  memo text,
  batch text,
  created_by uuid references public.members(id) on delete set null,
  created_at timestamptz not null default now(),
  claimed_by uuid references public.members(id) on delete set null,
  claimed_at timestamptz,
  unique (email, batch)
);
create index if not exists coin_pending_open on public.coin_pending_grants (email) where claimed_at is null;

-- 항목별 가격 (코드 수정 없이 여기서 바꿈)
create table if not exists public.coin_prices (
  app_key text not null references public.apps(key),
  item text not null,
  coins int not null check (coins > 0),
  primary key (app_key, item)
);

-- 한 번 푼 항목 기록 (다시 볼 때는 무료)
create table if not exists public.unlocked_items (
  member_id uuid not null references public.members(id) on delete cascade,
  app_key text not null references public.apps(key),
  item text not null,
  ref text not null,
  meta jsonb,
  created_at timestamptz not null default now(),
  primary key (member_id, app_key, item, ref)
);

-- 충전 상품 (구글 플레이 상품 ID -> 코인 수). 지급 코인은 이 표가 정함.
create table if not exists public.coin_products (
  product_id text primary key,
  coins int not null check (coins > 0),
  price_krw int not null check (price_krw >= 0),
  active boolean not null default true,
  sort int not null default 0
);

-- 결제 기록. 법정 보존 때문에 회원이 탈퇴해도 지우지 않음(member_id만 비움).
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  member_id uuid references public.members(id) on delete set null,
  member_email text,
  provider text not null check (provider in ('google_play')),
  product_id text not null,
  order_id text,
  purchase_token text not null,
  coins int not null check (coins > 0),
  amount_krw int,
  status text not null default 'credited' check (status in ('credited','refunded')),
  raw jsonb,
  created_at timestamptz not null default now(),
  refunded_at timestamptz,
  unique (provider, purchase_token)
);
create index if not exists payments_member_recent on public.payments (member_id, created_at desc);

-- ------------------------------------------------------------
-- 2) 기본 가격 / 상품
--    (다른 앱 가격은 해당 앱을 작업할 때 같은 방식으로 추가)
-- ------------------------------------------------------------
insert into public.coin_prices (app_key, item, coins) values
  ('color-tarot',      'reading',       1),
  ('numerology-tarot', 'result',        1),
  ('numerology-tarot', 'compatibility', 1)
on conflict (app_key, item) do nothing;

-- 구글 플레이 콘솔에 같은 상품 ID로 "관리형 상품(소비성)"을 만들어야 함.
-- 가격/코인을 바꾸려면 여기를 고치고 다시 실행 (재실행 시 덮어씀).
insert into public.coin_products (product_id, coins, price_krw, sort) values
  ('coins_15',   15, 1900, 1),
  ('coins_45',   45, 4900, 2),
  ('coins_100', 100, 9900, 3)
on conflict (product_id) do update
  set coins = excluded.coins, price_krw = excluded.price_krw, sort = excluded.sort;

-- ------------------------------------------------------------
-- 3) 내부 함수 (앱이 직접 부를 수 없음)
-- ------------------------------------------------------------
-- 지갑에 +/- 를 적용하고 내역을 남김. 반환: 새 잔액, 이미 지급된 건이면 null.
-- 잔액 부족이면 'insufficient_coins' 예외.
create or replace function public._wallet_apply(
  p_member uuid, p_delta int, p_kind text, p_app_key text,
  p_ref text, p_memo text, p_grant_date date default null, p_granted_by uuid default null)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance int;
  v_new int;
  v_id bigint;
begin
  insert into public.wallets (member_id) values (p_member) on conflict do nothing;
  select balance into v_balance from public.wallets where member_id = p_member for update;
  v_new := v_balance + p_delta;
  if v_new < 0 then
    raise exception 'insufficient_coins';
  end if;

  insert into public.coin_ledger (member_id, delta, balance_after, kind, app_key, ref, memo, grant_date, granted_by)
    values (p_member, p_delta, v_new, p_kind, p_app_key, p_ref, p_memo, p_grant_date, p_granted_by)
    on conflict do nothing
    returning id into v_id;
  if v_id is null then
    return null;  -- 같은 지급이 이미 있음: 아무것도 바꾸지 않음
  end if;

  update public.wallets set balance = v_new, updated_at = now() where member_id = p_member;
  return v_new;
end;
$$;

create or replace function public._price(p_app_key text, p_item text)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare v int;
begin
  select coins into v from public.coin_prices where app_key = p_app_key and item = p_item;
  if v is null then
    raise exception 'unknown_price:%/%', p_app_key, p_item;
  end if;
  return v;
end;
$$;

-- 항목 하나를 풀고(코인 차감) 기록함. 이미 푼 항목이면 무료.
create or replace function public._unlock(
  p_member uuid, p_app_key text, p_item text, p_ref text, p_meta jsonb default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cost int;
  v_balance int;
  v_label text := case p_item when 'result' then '성향 해설 열기' when 'compatibility' then '궁합 보기' else p_item end;
begin
  -- 같은 사람의 동시 요청이 이중 차감되지 않도록 지갑 행을 먼저 잠금
  insert into public.wallets (member_id) values (p_member) on conflict do nothing;
  perform 1 from public.wallets where member_id = p_member for update;

  if exists (select 1 from public.unlocked_items
             where member_id = p_member and app_key = p_app_key and item = p_item and ref = p_ref) then
    select balance into v_balance from public.wallets where member_id = p_member;
    return jsonb_build_object('ok', true, 'already', true, 'balance', v_balance);
  end if;

  v_cost := public._price(p_app_key, p_item);
  begin
    v_balance := public._wallet_apply(p_member, -v_cost, 'spend', p_app_key, p_item || ':' || p_ref, v_label);
  exception when raise_exception then
    if sqlerrm = 'insufficient_coins' then
      select balance into v_balance from public.wallets where member_id = p_member;
      return jsonb_build_object('ok', false, 'reason', 'insufficient_coins', 'balance', v_balance, 'cost', v_cost);
    end if;
    raise;
  end;

  insert into public.unlocked_items (member_id, app_key, item, ref, meta)
    values (p_member, p_app_key, p_item, p_ref, p_meta)
    on conflict do nothing;
  return jsonb_build_object('ok', true, 'already', false, 'balance', v_balance, 'cost', v_cost);
end;
$$;

-- ------------------------------------------------------------
-- 4) 앱이 부르는 함수 (로그인한 본인에게만 적용)
-- ------------------------------------------------------------
-- 앱을 열 때 호출: 가입 보너스(1회) + 오늘의 출석 보너스(하루 1회). 여러 번 불러도 안전.
create or replace function public.claim_free_coins()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Seoul')::date;
  v_signup int := 0;
  v_attend int := 0;
  v_admin int := 0;
  v_balance int;
  v_email text;
  v_pending record;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_logged_in');
  end if;
  select lower(email) into v_email from public.members where id = v_uid;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'no_member');
  end if;

  if public._wallet_apply(v_uid, 5, 'signup_bonus', null, null, '가입 보너스') is not null then
    v_signup := 5;
  end if;
  if public._wallet_apply(v_uid, 1, 'daily_attendance', null, null, '출석 보너스', v_today) is not null then
    v_attend := 1;
  end if;

  -- 운영자가 이 이메일로 미리 등록해둔 지급(가입 전 수강생)이 있으면 지금 지급
  if v_email is not null then
    for v_pending in
      select id, coins, memo, created_by from public.coin_pending_grants
      where email = v_email and claimed_at is null order by id for update
    loop
      if public._wallet_apply(v_uid, v_pending.coins, 'admin_grant', null, 'pending:' || v_pending.id,
                              coalesce(v_pending.memo, '운영자 지급'), null, v_pending.created_by) is not null then
        v_admin := v_admin + v_pending.coins;
      end if;
      update public.coin_pending_grants set claimed_at = now(), claimed_by = v_uid where id = v_pending.id;
    end loop;
  end if;

  select coalesce(balance, 0) into v_balance from public.wallets where member_id = v_uid;
  return jsonb_build_object('ok', true, 'signup', v_signup, 'attendance', v_attend, 'admin', v_admin,
                            'balance', coalesce(v_balance, 0));
end;
$$;

-- 컬러타로 등 "AI 리딩" 앱: 리딩 저장 + 코인 차감을 한 번에(둘 다 되거나 둘 다 안 됨).
create or replace function public.save_reading_with_spend(
  p_app_key text, p_card_id bigint, p_mood text, p_memo text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_cost int;
  v_reading_id bigint;
  v_balance int;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_logged_in');
  end if;
  if length(coalesce(p_memo, '')) > 20000 or length(coalesce(p_mood, '')) > 2000 then
    return jsonb_build_object('ok', false, 'reason', 'too_long');
  end if;

  v_cost := public._price(p_app_key, 'reading');
  begin
    insert into public.readings (user_id, card_id, mood_input, memo, app_key)
      values (v_uid, p_card_id, p_mood, p_memo, p_app_key)
      returning id into v_reading_id;
    v_balance := public._wallet_apply(v_uid, -v_cost, 'spend', p_app_key, v_reading_id::text, '리딩');
  exception when raise_exception then
    if sqlerrm = 'insufficient_coins' then
      -- 이 블록 안의 변경(리딩 저장)은 자동으로 취소됨
      select coalesce(balance, 0) into v_balance from public.wallets where member_id = v_uid;
      return jsonb_build_object('ok', false, 'reason', 'insufficient_coins',
                                'balance', coalesce(v_balance, 0), 'cost', v_cost);
    end if;
    raise;
  end;

  return jsonb_build_object('ok', true, 'reading_id', v_reading_id, 'balance', v_balance, 'cost', v_cost);
end;
$$;

-- 수강생 코드: 인증 + 코인 지급. (결과 문자열은 기존과 동일)
alter table public.class_codes add column if not exists coins int not null default 100 check (coins >= 0);

create or replace function public.redeem_class_code(p_code text, p_app_key text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_row public.class_codes%rowtype;
begin
  if v_uid is null then
    return 'not_logged_in';
  end if;

  select * into v_row from public.class_codes
    where code = v_code and app_key = p_app_key
    for update;

  if not found or not v_row.active then
    return 'invalid';
  end if;
  if v_row.expires_at is not null and v_row.expires_at < now() then
    return 'expired';
  end if;

  if not exists (
    select 1 from public.class_code_redemptions
    where code = v_code and app_key = p_app_key and member_id = v_uid
  ) then
    if v_row.max_uses is not null and v_row.use_count >= v_row.max_uses then
      return 'full';
    end if;
    insert into public.class_code_redemptions (code, app_key, member_id)
      values (v_code, p_app_key, v_uid);
    update public.class_codes set use_count = use_count + 1
      where code = v_code and app_key = p_app_key;
    if v_row.coins > 0 then
      perform public._wallet_apply(v_uid, v_row.coins, 'class_code', p_app_key,
                                   v_code || '@' || p_app_key, '수강생 코드 ' || v_code);
    end if;
  end if;

  insert into public.enrollments (member_id, app_key, role)
    values (v_uid, p_app_key, 'student')
    on conflict (member_id, app_key) do update set role = 'student';

  return 'ok';
end;
$$;

-- ------------------------------------------------------------
-- 5) 우리 서버 전용 함수 (service_role 만 실행 가능)
-- ------------------------------------------------------------
-- 구글 결제 검증이 끝난 구매를 지급. 같은 구매 토큰은 한 번만 지급됨.
create or replace function public.credit_purchase(
  p_member uuid, p_provider text, p_product_id text,
  p_order_id text, p_token text, p_raw jsonb default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product public.coin_products%rowtype;
  v_email text;
  v_payment uuid;
  v_balance int;
begin
  select * into v_product from public.coin_products where product_id = p_product_id and active;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'unknown_product');
  end if;
  select email into v_email from public.members where id = p_member;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'unknown_member');
  end if;

  insert into public.payments (member_id, member_email, provider, product_id, order_id,
                               purchase_token, coins, amount_krw, raw)
    values (p_member, v_email, p_provider, p_product_id, p_order_id, p_token,
            v_product.coins, v_product.price_krw, p_raw)
    on conflict (provider, purchase_token) do nothing
    returning id into v_payment;

  if v_payment is null then
    select coalesce(balance, 0) into v_balance from public.wallets where member_id = p_member;
    return jsonb_build_object('ok', true, 'already', true, 'balance', coalesce(v_balance, 0));
  end if;

  v_balance := public._wallet_apply(p_member, v_product.coins, 'purchase', null,
                                    v_payment::text, '코인 충전 ' || v_product.coins || '개');
  return jsonb_build_object('ok', true, 'already', false, 'balance', v_balance,
                            'coins', v_product.coins, 'payment_id', v_payment);
end;
$$;

-- 환불: 지급했던 코인을 회수. 이미 쓴 코인이 있으면 남은 잔액만큼만 회수.
create or replace function public.refund_purchase(p_provider text, p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pay public.payments%rowtype;
  v_balance int;
  v_take int;
begin
  select * into v_pay from public.payments
    where provider = p_provider and purchase_token = p_token for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_pay.status = 'refunded' then
    return jsonb_build_object('ok', true, 'already', true);
  end if;

  if v_pay.member_id is not null then
    insert into public.wallets (member_id) values (v_pay.member_id) on conflict do nothing;
    select balance into v_balance from public.wallets where member_id = v_pay.member_id for update;
    v_take := least(v_balance, v_pay.coins);
    if v_take > 0 then
      perform public._wallet_apply(v_pay.member_id, -v_take, 'refund', null, v_pay.id::text,
                                   '결제 환불로 회수 ' || v_take || '개');
    end if;
  end if;
  update public.payments set status = 'refunded', refunded_at = now() where id = v_pay.id;
  return jsonb_build_object('ok', true, 'recovered', coalesce(v_take, 0), 'coins', v_pay.coins);
end;
$$;

-- ------------------------------------------------------------
-- 6) 권한: 읽기만, 쓰기는 전부 막음
-- ------------------------------------------------------------
alter table public.wallets         enable row level security;
alter table public.coin_ledger     enable row level security;
alter table public.coin_prices     enable row level security;
alter table public.unlocked_items  enable row level security;
alter table public.coin_products   enable row level security;
alter table public.payments        enable row level security;
alter table public.admins          enable row level security;
alter table public.coin_pending_grants enable row level security;

revoke all on public.wallets, public.coin_ledger, public.coin_prices,
              public.unlocked_items, public.coin_products, public.payments,
              public.admins, public.coin_pending_grants
  from anon, authenticated;

grant select on public.wallets, public.coin_ledger, public.unlocked_items, public.payments
  to authenticated;
grant select on public.coin_prices, public.coin_products to anon, authenticated;

drop policy if exists "own wallet"   on public.wallets;
create policy "own wallet"   on public.wallets        for select to authenticated using (member_id = auth.uid());
drop policy if exists "own ledger"   on public.coin_ledger;
create policy "own ledger"   on public.coin_ledger    for select to authenticated using (member_id = auth.uid());
drop policy if exists "own unlocks"  on public.unlocked_items;
create policy "own unlocks"  on public.unlocked_items for select to authenticated using (member_id = auth.uid());
drop policy if exists "own payments" on public.payments;
create policy "own payments" on public.payments       for select to authenticated using (member_id = auth.uid());
drop policy if exists "public prices"   on public.coin_prices;
create policy "public prices"   on public.coin_prices   for select using (true);
drop policy if exists "public products" on public.coin_products;
create policy "public products" on public.coin_products for select using (active);

-- 함수: 기본적으로 아무도 못 부르게 한 뒤 필요한 곳에만 허용
revoke all on function public._wallet_apply(uuid,int,text,text,text,text,date,uuid) from public, anon, authenticated;
revoke all on function public._price(text,text)                                from public, anon, authenticated;
revoke all on function public._unlock(uuid,text,text,text,jsonb)               from public, anon, authenticated;
revoke all on function public.claim_free_coins()                               from public, anon;
revoke all on function public.save_reading_with_spend(text,bigint,text,text)   from public, anon;
revoke all on function public.redeem_class_code(text,text)                     from public;
revoke all on function public.credit_purchase(uuid,text,text,text,text,jsonb)  from public, anon, authenticated;
revoke all on function public.refund_purchase(text,text)                       from public, anon, authenticated;

grant execute on function public.claim_free_coins()                             to authenticated;
grant execute on function public.save_reading_with_spend(text,bigint,text,text) to authenticated;
grant execute on function public.redeem_class_code(text,text)                   to anon, authenticated;
grant execute on function public.credit_purchase(uuid,text,text,text,text,jsonb) to service_role;
grant execute on function public.refund_purchase(text,text)                      to service_role;

-- ============================================================
-- 운영 메모 (SQL Editor에서 필요할 때)
--   코인 수동 지급:  select public._wallet_apply('<member uuid>', 20, 'adjust', null, null, '관리자 지급');
--     (대시보드 SQL Editor는 소유자 권한이라 실행 가능. 앱에서는 불가)
--   가격 변경:       update public.coin_prices set coins = 2 where app_key='color-tarot' and item='reading';
--   코드별 지급량:   update public.class_codes set coins = 50 where code = 'OZMA-2026-COLOR';
--   내 잔액 확인:    select m.email, w.balance from public.wallets w join public.members m on m.id = w.member_id order by w.balance desc;
-- ============================================================
