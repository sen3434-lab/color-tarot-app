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
