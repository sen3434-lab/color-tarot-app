-- ============================================================
-- 보안 수정 3 — members.email 위조 막기
--
-- 문제: 로그인한 사람이 자기 members 행에 "아무 이메일"이나 쓰거나 고칠 수 있음.
--   그런데 아래 기능들이 members.email 을 "그 사람의 이메일"이라고 믿고 씀:
--     - 운영자가 미리 등록한 코인 지급(가입 전 수강생)을 이메일로 찾아 지급
--     - 수강생 이메일 명단(student_emails)과 맞춰 수강생 권한 부여
--   => 남의 이메일로 바꿔 적으면 그 사람 몫의 코인/수강생 권한을 가로챌 수 있음.
--
-- 수정: members 에 저장될 때마다 이메일을 "로그인 계정(auth.users)의 실제 이메일"로
--   강제로 덮어씀. 앱 코드는 바꿀 필요 없음. 재실행해도 안전.
--   (이름 display_name 은 그대로 본인이 수정 가능)
-- ============================================================

create or replace function public._force_member_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_email text;
begin
  select email into v_auth_email from auth.users where id = new.id;
  if v_auth_email is not null then
    new.email := v_auth_email;
  end if;
  return new;
end;
$$;

revoke all on function public._force_member_email() from public, anon, authenticated;

drop trigger if exists trg_force_member_email on public.members;
create trigger trg_force_member_email
  before insert or update of email on public.members
  for each row execute function public._force_member_email();

-- 이미 어긋나 있는 행 확인 (결과가 0줄이면 지금까지 위조된 이메일은 없다는 뜻)
select m.id, m.email as members_email, u.email as real_login_email
from public.members m
join auth.users u on u.id = m.id
where lower(coalesce(m.email, '')) <> lower(coalesce(u.email, ''));
