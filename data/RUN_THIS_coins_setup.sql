-- ============================================================
-- OZ 타로 코인 지갑 + 넘버스 코인 + 운영자 도구  (한 번에 실행)
--
-- 실행 순서 (중요):
--   1) security_1_check.sql  실행 -> 결과를 저에게 보여주기
--   2) security_2_fix_and_audit.sql 실행
--   3) 이 파일 전체를 실행   <-- 지금 이 파일
--   4) 맨 아래 "운영자 등록" 한 줄을 본인 이메일로 실행
--
-- 이 파일 = coins_1_wallet.sql + coins_2_numerology.sql + coins_4_admin.sql
-- 재실행해도 안전합니다. (수강생 코드 SQL을 이미 실행하셨다는 전제)
-- ============================================================

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


-- ============================================================
-- OZ 넘버스 타로 — 코인으로 해설 열기
--
-- 먼저 coins_1_wallet.sql (공용 코인 지갑)을 실행한 뒤 한 번 실행하세요.
-- (coins_1 파일은 color-tarot-app/data 에 있습니다. 같은 Supabase 프로젝트.)
--
-- 무엇이 코인으로 열리나
--   성향 해설  : 프로필 1명의 외적(양력)+내적(음력) 4가지 해설 = 1코인
--   궁합       : 프로필 2명의 궁합 점수+해설(연인/배우자면 속궁합 포함) = 1코인
--   한 번 연 것은 다시 볼 때 무료 (프로필·숫자 조합별로 기록됨)
--   소울넘버와 카드 이름/이미지는 코인 없이 보임
--   가격은 coin_prices 표에서 바꿈 (app_key='numerology-tarot')
--
-- 왜 함수로 내주나
--   해설 표가 "누구나 읽기"로 열려 있으면 화면만 가려도 요청 한 번으로
--   전체를 가져갈 수 있음. 그래서 표 직접 읽기를 막고, 코인을 차감한
--   함수만 해설을 돌려주게 함. (관리 스크립트는 service_role 이라 영향 없음)
--
-- 재실행해도 안전합니다.
-- ============================================================

-- 가족/친구 프로필도 이제 누구나 추가 가능 (옛 유료 제한 제거).
-- 대신 계정당 30개까지만.
drop trigger if exists trg_enforce_profile_tier_limit on public.profiles;
drop function if exists public.enforce_profile_tier_limit();

create or replace function public.enforce_profile_cap()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select count(*) from public.profiles
      where member_id = new.member_id and app_key = new.app_key) >= 30 then
    raise exception 'profile_limit: at most 30 profiles per member';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_enforce_profile_cap on public.profiles;
create trigger trg_enforce_profile_cap
  before insert on public.profiles
  for each row execute function public.enforce_profile_cap();

-- ------------------------------------------------------------
-- 내부: 카드 번호 하나의 해설 묶음 (해설이 아직 없으면 JSON null)
-- ------------------------------------------------------------
create or replace function public._numerology_interp(p_arcana int, p_aspect text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select jsonb_build_object(
      'arcana_number', i.arcana_number,
      'aspect', i.aspect,
      'title', i.title,
      'personality_text', i.personality_text,
      'wealth_text', i.wealth_text,
      'love_text', i.love_text,
      'health_text', i.health_text,
      'card_name', tc.name)
    from public.numerology_interpretations i
    left join public.tarot_cards tc on tc.id = i.tarot_card_id
    where i.arcana_number = p_arcana and i.aspect = p_aspect
  ), 'null'::jsonb);
$$;

-- 내부: 두 프로필의 궁합 내용 + 열기 기록용 ref
create or replace function public._numerology_compat(
  p_uid uuid, p_a bigint, p_b bigint,
  p_a_ext int, p_b_ext int, p_a_int int, p_b_int int)
returns jsonb   -- {ref, romantic, general, intimacy, card_a_name, card_b_name} 또는 {error}
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_rel_a text;
  v_rel_b text;
  v_romantic boolean;
  v_general jsonb;
  v_intimacy jsonb := 'null'::jsonb;
begin
  if p_a is null or p_b is null or p_a = p_b then
    return jsonb_build_object('error', 'bad_profiles');
  end if;
  if coalesce(p_a_ext, -1) not between 0 and 21 or coalesce(p_b_ext, -1) not between 0 and 21
     or coalesce(p_a_int, -1) not between 0 and 21 or coalesce(p_b_int, -1) not between 0 and 21 then
    return jsonb_build_object('error', 'bad_numbers');
  end if;

  select relation into v_rel_a from public.profiles
    where id = p_a and member_id = p_uid and app_key = 'numerology-tarot';
  select relation into v_rel_b from public.profiles
    where id = p_b and member_id = p_uid and app_key = 'numerology-tarot';
  if v_rel_a is null or v_rel_b is null then
    return jsonb_build_object('error', 'no_profile');
  end if;

  -- 속궁합은 "본인 + 연인/배우자" 조합에서만 (클라이언트 말은 믿지 않음)
  v_romantic := (v_rel_a = '본인' and v_rel_b in ('연인', '배우자'))
             or (v_rel_b = '본인' and v_rel_a in ('연인', '배우자'));

  select jsonb_build_object('summary_text', summary_text, 'score', score) into v_general
    from public.compatibility_matrix
    where card_a_number = least(p_a_ext, p_b_ext) and card_b_number = greatest(p_a_ext, p_b_ext)
      and kind = 'general';

  if v_romantic then
    select jsonb_build_object('summary_text', summary_text, 'score', score) into v_intimacy
      from public.compatibility_matrix
      where card_a_number = least(p_a_int, p_b_int) and card_b_number = greatest(p_a_int, p_b_int)
        and kind = 'intimacy';
  end if;

  return jsonb_build_object(
    'ref', least(p_a, p_b) || '-' || greatest(p_a, p_b)
           || ':' || least(p_a_ext, p_b_ext) || '-' || greatest(p_a_ext, p_b_ext)
           || ':' || case when v_romantic then least(p_a_int, p_b_int) || '-' || greatest(p_a_int, p_b_int) else 'x' end,
    'romantic', v_romantic,
    'general', coalesce(v_general, 'null'::jsonb),
    'intimacy', coalesce(v_intimacy, 'null'::jsonb),
    'card_a_name', public._numerology_interp(p_a_ext, 'external')->>'card_name',
    'card_b_name', public._numerology_interp(p_b_ext, 'external')->>'card_name');
end;
$$;

-- ------------------------------------------------------------
-- 앱이 부르는 함수
-- ------------------------------------------------------------
-- 성향 해설 열기 (코인 1개, 이미 열었으면 무료)
create or replace function public.numerology_unlock_result(p_profile_id bigint, p_ext int, p_int int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_res jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_logged_in');
  end if;
  if coalesce(p_ext, -1) not between 0 and 21 or coalesce(p_int, -1) not between 0 and 21 then
    return jsonb_build_object('ok', false, 'reason', 'bad_numbers');
  end if;
  if not exists (select 1 from public.profiles
                 where id = p_profile_id and member_id = v_uid and app_key = 'numerology-tarot') then
    return jsonb_build_object('ok', false, 'reason', 'no_profile');
  end if;

  v_res := public._unlock(v_uid, 'numerology-tarot', 'result',
                          p_profile_id || ':' || p_ext || '-' || p_int,
                          jsonb_build_object('ext', p_ext, 'int', p_int));
  if not coalesce((v_res->>'ok')::boolean, false) then
    return v_res;
  end if;
  return v_res || jsonb_build_object(
    'external', public._numerology_interp(p_ext, 'external'),
    'internal', public._numerology_interp(p_int, 'internal'));
end;
$$;

-- 이미 연 해설 다시 보기 (코인 차감 없음, 안 열었으면 locked)
create or replace function public.numerology_peek_result(p_profile_id bigint, p_ext int, p_int int)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_logged_in');
  end if;
  if coalesce(p_ext, -1) not between 0 and 21 or coalesce(p_int, -1) not between 0 and 21 then
    return jsonb_build_object('ok', false, 'reason', 'bad_numbers');
  end if;
  if not exists (select 1 from public.unlocked_items
                 where member_id = v_uid and app_key = 'numerology-tarot' and item = 'result'
                   and ref = p_profile_id || ':' || p_ext || '-' || p_int) then
    return jsonb_build_object('ok', false, 'reason', 'locked');
  end if;
  return jsonb_build_object(
    'ok', true, 'already', true,
    'external', public._numerology_interp(p_ext, 'external'),
    'internal', public._numerology_interp(p_int, 'internal'));
end;
$$;

-- 궁합 열기 (코인 1개, 이미 열었으면 무료)
create or replace function public.numerology_unlock_compat(
  p_a bigint, p_b bigint, p_a_ext int, p_b_ext int, p_a_int int, p_b_int int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_c jsonb;
  v_res jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_logged_in');
  end if;
  v_c := public._numerology_compat(v_uid, p_a, p_b, p_a_ext, p_b_ext, p_a_int, p_b_int);
  if v_c ? 'error' then
    return jsonb_build_object('ok', false, 'reason', v_c->>'error');
  end if;

  v_res := public._unlock(v_uid, 'numerology-tarot', 'compatibility', v_c->>'ref', null);
  if not coalesce((v_res->>'ok')::boolean, false) then
    return v_res;
  end if;
  return v_res || (v_c - 'ref');
end;
$$;

create or replace function public.numerology_peek_compat(
  p_a bigint, p_b bigint, p_a_ext int, p_b_ext int, p_a_int int, p_b_int int)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_c jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_logged_in');
  end if;
  v_c := public._numerology_compat(v_uid, p_a, p_b, p_a_ext, p_b_ext, p_a_int, p_b_int);
  if v_c ? 'error' then
    return jsonb_build_object('ok', false, 'reason', v_c->>'error');
  end if;
  if not exists (select 1 from public.unlocked_items
                 where member_id = v_uid and app_key = 'numerology-tarot'
                   and item = 'compatibility' and ref = v_c->>'ref') then
    return jsonb_build_object('ok', false, 'reason', 'locked');
  end if;
  return jsonb_build_object('ok', true, 'already', true) || (v_c - 'ref');
end;
$$;

-- ------------------------------------------------------------
-- 권한: 해설/궁합 표 직접 읽기 차단, 함수만 허용
-- ------------------------------------------------------------
drop policy if exists "public can read numerology_interpretations" on public.numerology_interpretations;
drop policy if exists "public can read compatibility_matrix" on public.compatibility_matrix;
revoke select on public.numerology_interpretations, public.compatibility_matrix from anon, authenticated;

revoke all on function public._numerology_interp(int,text)                          from public, anon, authenticated;
revoke all on function public._numerology_compat(uuid,bigint,bigint,int,int,int,int) from public, anon, authenticated;
revoke all on function public.numerology_unlock_result(bigint,int,int)              from public, anon;
revoke all on function public.numerology_peek_result(bigint,int,int)                from public, anon;
revoke all on function public.numerology_unlock_compat(bigint,bigint,int,int,int,int) from public, anon;
revoke all on function public.numerology_peek_compat(bigint,bigint,int,int,int,int)   from public, anon;

grant execute on function public.numerology_unlock_result(bigint,int,int)              to authenticated;
grant execute on function public.numerology_peek_result(bigint,int,int)                to authenticated;
grant execute on function public.numerology_unlock_compat(bigint,bigint,int,int,int,int) to authenticated;
grant execute on function public.numerology_peek_compat(bigint,bigint,int,int,int,int)   to authenticated;


-- ============================================================
-- 운영자 도구: 앱에서 수강생 이메일을 입력해 코인 지급
--
-- coins_1_wallet.sql 을 먼저 실행한 뒤 한 번 실행하세요. 재실행 안전.
--
-- 동작
--   - 운영자(admins 표에 등록된 계정)만 쓸 수 있음. 일반 사용자가 호출하면 거절.
--   - 이메일을 줄바꿈/쉼표/공백으로 여러 개 붙여넣으면 한 번에 처리.
--   - 이미 가입한 사람 -> 즉시 코인 지급
--   - 아직 가입 안 한 사람 -> "가입하면 자동 지급"으로 대기 (그 이메일로 가입하고
--     로그인하는 순간 지급됨. 가입 확인 메일 인증이 켜져 있어야 안전: 지금 켜져 있음)
--   - 화면에서 두 번 눌러도 중복 지급되지 않음 (묶음 번호 batch 로 막음)
--   - 누가 언제 얼마를 줬는지 coin_ledger.granted_by 에 남음
--   - 한 번에 최대 200명, 1인당 1~5000코인
-- ============================================================

-- 내가 운영자인가? (화면에서 운영자 메뉴를 보여줄지 판단용)
create or replace function public.am_i_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admins where member_id = auth.uid());
$$;

-- 코인 지급
create or replace function public.admin_grant_coins(p_emails text, p_coins int, p_memo text, p_batch text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_list text[];
  v_email text;
  v_member uuid;
  v_memo text;
  v_granted text[] := '{}';
  v_pending text[] := '{}';
  v_invalid text[] := '{}';
  v_already text[] := '{}';
  v_pid bigint;
begin
  if v_uid is null or not exists (select 1 from public.admins where member_id = v_uid) then
    return jsonb_build_object('ok', false, 'reason', 'not_admin');
  end if;
  if p_coins is null or p_coins < 1 or p_coins > 5000 then
    return jsonb_build_object('ok', false, 'reason', 'bad_coins');
  end if;
  if coalesce(length(p_batch), 0) < 8 then
    return jsonb_build_object('ok', false, 'reason', 'bad_batch');
  end if;

  select coalesce(array_agg(distinct lower(btrim(x))), '{}') into v_list
    from regexp_split_to_table(coalesce(p_emails, ''), '[\s,;]+') as x
    where btrim(x) <> '';
  if coalesce(array_length(v_list, 1), 0) = 0 then
    return jsonb_build_object('ok', false, 'reason', 'no_emails');
  end if;
  if array_length(v_list, 1) > 200 then
    return jsonb_build_object('ok', false, 'reason', 'too_many');
  end if;

  v_memo := left(coalesce(nullif(btrim(p_memo), ''), '운영자 지급'), 100);

  foreach v_email in array v_list loop
    if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
      v_invalid := v_invalid || v_email;
      continue;
    end if;

    select id into v_member from public.members where lower(email) = v_email limit 1;
    if v_member is not null then
      if public._wallet_apply(v_member, p_coins, 'admin_grant', null, 'batch:' || p_batch, v_memo, null, v_uid) is null then
        v_already := v_already || v_email;
      else
        v_granted := v_granted || v_email;
      end if;
    else
      insert into public.coin_pending_grants (email, coins, memo, batch, created_by)
        values (v_email, p_coins, v_memo, p_batch, v_uid)
        on conflict (email, batch) do nothing
        returning id into v_pid;
      if v_pid is null then
        v_already := v_already || v_email;
      else
        v_pending := v_pending || v_email;
      end if;
      v_pid := null;
    end if;
    v_member := null;
  end loop;

  return jsonb_build_object('ok', true, 'coins', p_coins,
    'granted', to_jsonb(v_granted), 'pending', to_jsonb(v_pending),
    'invalid', to_jsonb(v_invalid), 'already', to_jsonb(v_already));
end;
$$;

-- 최근 지급 내역 + 아직 가입 안 해서 대기 중인 목록
create or replace function public.admin_recent()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.admins where member_id = auth.uid()) then
    return jsonb_build_object('ok', false, 'reason', 'not_admin');
  end if;
  return jsonb_build_object('ok', true,
    'pending', coalesce((
      select jsonb_agg(jsonb_build_object('id', id, 'email', email, 'coins', coins, 'memo', memo, 'created_at', created_at) order by id desc)
      from (select * from public.coin_pending_grants where claimed_at is null order by id desc limit 100) p), '[]'::jsonb),
    'granted', coalesce((
      select jsonb_agg(jsonb_build_object('email', m.email, 'coins', l.delta, 'memo', l.memo, 'created_at', l.created_at) order by l.id desc)
      from (select * from public.coin_ledger where kind = 'admin_grant' order by id desc limit 50) l
      join public.members m on m.id = l.member_id), '[]'::jsonb));
end;
$$;

-- 잘못 등록한 "가입 대기" 지급 취소 (아직 지급 안 된 것만)
create or replace function public.admin_cancel_pending(p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.admins where member_id = auth.uid()) then
    return jsonb_build_object('ok', false, 'reason', 'not_admin');
  end if;
  delete from public.coin_pending_grants where id = p_id and claimed_at is null;
  return jsonb_build_object('ok', found);
end;
$$;

revoke all on function public.am_i_admin()                                   from public, anon;
revoke all on function public.admin_grant_coins(text,int,text,text)          from public, anon;
revoke all on function public.admin_recent()                                 from public, anon;
revoke all on function public.admin_cancel_pending(bigint)                   from public, anon;
grant execute on function public.am_i_admin()                                to authenticated;
grant execute on function public.admin_grant_coins(text,int,text,text)       to authenticated;
grant execute on function public.admin_recent()                              to authenticated;
grant execute on function public.admin_cancel_pending(bigint)                to authenticated;

-- ------------------------------------------------------------
-- 운영자 등록 (이 파일을 실행한 뒤, 한 번만 직접 실행)
--
-- 앱에 가입/로그인할 때 쓰는 "본인 이메일"로 바꿔서 실행하세요.
-- 그 이메일로 앱에 한 번이라도 로그인해서 members 에 행이 있어야 합니다.
--
--   insert into public.admins (member_id)
--   select id from public.members where lower(email) = lower('tarotozma@gmail.com')
--   on conflict do nothing;
--
-- 확인:  select m.email from public.admins a join public.members m on m.id = a.member_id;
-- 해제:  delete from public.admins where member_id = (select id from public.members where lower(email) = lower('...'));
-- ------------------------------------------------------------


-- ============================================================
-- 운영자 등록 (이 파일을 실행한 뒤)
-- 본인이 앱에 로그인할 때 쓰는 이메일로 바꿔서 실행하세요.
-- 그 이메일로 앱(컬러타로/넘버스)에 한 번 로그인해서 가입이 되어 있어야 합니다.
-- 결과에 이메일이 1줄 나오면 성공, 0줄이면 아직 가입 전이거나 이메일이 다른 것.
-- ============================================================
insert into public.admins (member_id)
select id from public.members where lower(email) = lower('tarotozma@gmail.com')
on conflict do nothing;

select m.email as operator from public.admins a join public.members m on m.id = a.member_id;
