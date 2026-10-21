-- ============================================================
-- 기존 수강생에게 코인 지급 (한 번만, 선택 사항)
--
-- 왜: 예전에는 수강생(role = 'student')이 "무제한"이었는데 코인제로 바뀌면서
--     오히려 줄어드는 셈이 됨. 이미 인증된 수강생에게 앱별 100코인을 지급.
--
-- 반드시 먼저 security_2_fix_and_audit.sql 의 마지막 표(감사)를 확인해서
-- 정상 경로(명단/코드/승인)로 수강생이 된 계정인지 보고, 의심스러운 계정은
-- 아래 where 조건에서 제외한 뒤 실행하세요.
--
-- 안전장치: 앱 + 계정당 한 번만 지급됨(재실행해도 중복 지급 없음).
-- 지급 수를 바꾸려면 아래 100 을 수정.
-- ============================================================

-- 1) 누구에게 얼마나 가는지 먼저 확인 (아무것도 바꾸지 않음)
select m.email, e.app_key, 100 as coins
from public.enrollments e
join public.members m on m.id = e.member_id
where e.role = 'student'
order by e.app_key, m.email;

-- 2) 확인이 끝났으면 아래를 실행 (위 select 는 지우거나 그대로 둬도 됨)
select e.app_key,
       m.email,
       public._wallet_apply(e.member_id, 100, 'class_code', e.app_key,
                            'legacy-student@' || e.app_key, '기존 수강생 코인 지급') as new_balance_or_null_if_already_granted
from public.enrollments e
join public.members m on m.id = e.member_id
where e.role = 'student'
order by e.app_key, m.email;
