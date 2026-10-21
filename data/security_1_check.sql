-- ============================================================
-- 보안 점검 1/2 — 읽기 전용 (아무것도 바꾸지 않음)
--
-- 확인하려는 것: 로그인한 일반 사용자가 enrollments 테이블에서
-- 자기 행의 role('student') / subscription_status('active')를
-- 직접 바꿀 수 있는지. 가능하면 수강생 코드·결제 없이도 수강생/유료
-- 권한을 가질 수 있음.
--
-- Supabase SQL Editor에 전체를 붙여넣고 Run → 결과 표를 캡처하거나
-- 복사해서 알려주세요. (수정은 security_2 파일에서 하며, 반드시
-- 이 점검을 먼저 실행한 뒤에 하세요. 순서를 바꾸면 수정 "후" 상태만
-- 보여서 원래 뚫려 있었는지 알 수 없어요.)
--
-- 읽는 법:
--  - kind=policy  : 행 단위 규칙(RLS). cmd가 INSERT/UPDATE/ALL 이고
--                   expr에 role 칸 제한이 전혀 없으면 위험 신호.
--  - kind=grant   : 칸(컬럼) 단위 권한. authenticated 에게
--                   enrollments 전체(whole table) INSERT/UPDATE 가
--                   있으면 role 도 바꿀 수 있다는 뜻.
-- ============================================================

select 'policy' as kind,
       tablename as object,
       policyname as name,
       cmd as detail,
       'USING: ' || coalesce(qual, '-') || '  |  CHECK: ' || coalesce(with_check, '-') as expr
from pg_policies
where schemaname = 'public'
  and tablename in ('enrollments', 'members', 'readings', 'verification_requests', 'profiles')

union all

select 'grant',
       table_name,
       grantee,
       privilege_type,
       '(whole table)'
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in ('enrollments', 'members', 'verification_requests')
  and grantee in ('anon', 'authenticated')
  and privilege_type in ('INSERT', 'UPDATE', 'DELETE')

union all

select 'grant-column',
       table_name,
       grantee,
       privilege_type,
       column_name
from information_schema.column_privileges
where table_schema = 'public'
  and table_name = 'enrollments'
  and grantee in ('anon', 'authenticated')
  and privilege_type in ('INSERT', 'UPDATE')
  and column_name in ('role', 'subscription_status', 'subscription_expires_at')

order by 1, 2, 3, 4;
