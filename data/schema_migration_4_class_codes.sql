-- ============================================================
-- 기수/반별 공용 수강생 코드 (class codes)
--
-- 기존: 수강생 한 명 한 명을 이메일 명단(student_emails)이나 1회용
--       코드(student_codes), 이름 승인 요청(verification_requests)으로
--       1:1 매칭해야 했음.
-- 변경: "OZMA-2026-A" 같은 공용 코드를 한 번 만들어 두고, 그 반
--       수강생 모두에게 같은 코드를 알려주면 각자 입력해서 인증.
--
-- - 코드는 (code, app_key) 단위라서 같은 문자열을 여러 앱에 쓸 수 있음
--   (앱마다 행을 하나씩 만들어야 함).
-- - max_uses(최대 인원)와 expires_at(만료일)은 선택. 비워두면 무제한.
--   만료/마감은 "새로 입력하는 사람"만 막고, 이미 인증된 수강생의
--   권한은 그대로 유지됨.
-- - 같은 사람이 같은 코드를 다시 입력해도 인원이 중복 차감되지 않음.
-- - 코드 목록은 클라이언트에서 읽을 수 없음(RLS 정책 없음). 앱은
--   redeem_class_code() 함수로만 검증하고, 코드 생성/관리는 Supabase
--   SQL Editor / Table Editor에서만 함.
-- - 기존 student_emails / student_codes / verification_requests,
--   verify_student_code(), recheck_student_status()는 건드리지 않음
--   (이미 인증된 수강생 영향 없음).
--
-- Supabase SQL Editor에서 한 번만 실행하세요. 재실행해도 안전합니다.
-- (컬러타로 / 넘버스 타로 / 같은 Supabase 프로젝트를 쓰는 모든 앱 공통)
-- ============================================================

create table if not exists public.class_codes (
  code text not null check (code = upper(code)),
  app_key text not null references public.apps(key),
  label text,                       -- 예: '2026 가을 1기'
  max_uses int check (max_uses is null or max_uses > 0),
  use_count int not null default 0,
  expires_at timestamptz,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (code, app_key)
);

create table if not exists public.class_code_redemptions (
  code text not null,
  app_key text not null,
  member_id uuid not null references public.members(id) on delete cascade,
  redeemed_at timestamptz not null default now(),
  primary key (code, app_key, member_id),
  foreign key (code, app_key) references public.class_codes(code, app_key) on delete cascade
);

alter table public.class_codes enable row level security;
alter table public.class_code_redemptions enable row level security;
-- 일부러 정책을 만들지 않음: 클라이언트는 두 테이블을 직접 읽거나 쓸 수 없고,
-- 아래 security definer 함수만 통과할 수 있음.

-- 결과 문자열: ok | invalid | expired | full | not_logged_in
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

  -- 같은 코드 동시 입력 시 인원 초과가 나지 않도록 행을 잠금
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
  end if;

  insert into public.enrollments (member_id, app_key, role)
    values (v_uid, p_app_key, 'student')
    on conflict (member_id, app_key) do update set role = 'student';

  return 'ok';
end;
$$;

revoke all on function public.redeem_class_code(text, text) from public;
grant execute on function public.redeem_class_code(text, text) to authenticated, anon;

-- ============================================================
-- 사용법 (필요할 때 SQL Editor에서 실행)
-- ============================================================
-- 코드 만들기 (앱마다 한 줄씩. max_uses / expires_at 은 생략 가능):
--   insert into public.class_codes (code, app_key, label, max_uses, expires_at) values
--     ('OZMA-2026-A', 'color-tarot',      '2026 가을 1기', 50, '2026-12-31 23:59:59+09'),
--     ('OZMA-2026-A', 'numerology-tarot', '2026 가을 1기', 50, '2026-12-31 23:59:59+09');
--
-- 현황 보기:
--   select code, app_key, label, use_count, max_uses, expires_at, active
--   from public.class_codes order by created_at desc;
--
-- 코드 끄기 / 다시 켜기 (이미 인증된 수강생은 영향 없음):
--   update public.class_codes set active = false where code = 'OZMA-2026-A';
--
-- 누가 입력했는지 보기:
--   select r.code, r.app_key, m.email, r.redeemed_at
--   from public.class_code_redemptions r join public.members m on m.id = r.member_id
--   order by r.redeemed_at desc;
-- ============================================================
