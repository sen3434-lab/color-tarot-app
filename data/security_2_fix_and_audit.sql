-- ============================================================
-- 보안 수정 2/2 — security_1_check.sql 을 먼저 실행한 뒤에 하세요.
--
-- 문제: 클라이언트(앱)가 enrollments 에 직접 INSERT/UPDATE 할 수 있고
-- 칸 제한이 없으면, 로그인한 누구나 자기 행의 role='student' 또는
-- subscription_status='active' 로 바꿔서 수강생 코드/결제를 건너뛸 수 있음.
--
-- 수정: 앱이 실제로 쓰는 칸만 남기고 나머지는 막음.
--   - INSERT : member_id, app_key         (처음 가입 시 자기 행 만들기)
--   - UPDATE : daily_reading_count, daily_reading_reset_date (일일 횟수)
--   role / subscription_status / subscription_expires_at 은 이제
--   서버 쪽(security definer 함수: redeem_class_code, verify_student_code,
--   recheck_student_status, 결제 승인 처리)과 Supabase 대시보드에서만 바뀜.
--   그 함수들은 테이블 소유자 권한으로 돌아서 이 변경의 영향을 받지 않음.
--
-- 되돌리기(필요할 때만):
--   grant insert, update on public.enrollments to authenticated;
--
-- 재실행해도 안전함. 마지막 표(감사)는 현재 수강생/유료로 등록된
-- 계정이 "정상 경로"로 그렇게 된 건지 보여줌.
-- ============================================================

revoke insert, update on public.enrollments from anon, authenticated;
grant insert (member_id, app_key) on public.enrollments to authenticated;
grant update (daily_reading_count, daily_reading_reset_date) on public.enrollments to authenticated;

-- ------------------------------------------------------------
-- 감사: 수강생/유료 계정 목록 + 정상 경로 증거
--   in_roster          이메일 명단(student_emails)에 있음
--   used_code          1회용 코드(student_codes)로 인증
--   approved_req       이름 승인 요청이 승인됨
--   redeemed_class_code 공용 코드로 인증
--   subscribed_legit   (결제 기능이 아직 없으므로 active 는 전부 의심 대상)
-- 네 칸이 전부 false 인 수강생 행은 수동으로 대시보드에서 올렸거나
-- (정상일 수 있음) 직접 조작했을 가능성이 있으니 확인해보세요.
-- ------------------------------------------------------------
select m.email,
       e.app_key,
       e.role,
       e.subscription_status,
       e.created_at::date as created,
       exists (select 1 from public.student_emails s
               where lower(s.email) = lower(m.email) and s.app_key = e.app_key) as in_roster,
       exists (select 1 from public.student_codes c
               where c.used_by = e.member_id and c.app_key = e.app_key)         as used_code,
       exists (select 1 from public.verification_requests v
               where v.member_id = e.member_id and v.app_key = e.app_key
                 and v.status = 'approved')                                      as approved_req,
       exists (select 1 from public.class_code_redemptions r
               where r.member_id = e.member_id and r.app_key = e.app_key)       as redeemed_class_code
from public.enrollments e
join public.members m on m.id = e.member_id
where e.role = 'student' or e.subscription_status = 'active'
order by e.created_at desc;
