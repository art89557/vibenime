-- VibeNime admin roles + ban system
-- ---------------------------------------------------------
-- Role hierarchy: super_admin > admin > user.
-- Super-admin set MANUAL via Supabase Dashboard untuk security.
-- Super-admin lalu bisa promote user lain ke admin via app.
--
-- Prerequisite: jalan sql/user_profiles.sql DULU.
--
-- Initial super-admin setup (run setelah cek user UUID kamu):
-- UPDATE public.user_profiles SET role = 'super_admin' WHERE user_id = 'YOUR_UUID';

create type user_role as enum ('user', 'admin', 'super_admin');

alter table public.user_profiles
  add column if not exists role user_role not null default 'user',
  add column if not exists banned_at timestamptz,
  add column if not exists banned_reason text,
  add column if not exists banned_by uuid references auth.users(id);

create index if not exists idx_user_profiles_role on public.user_profiles(role);
create index if not exists idx_user_profiles_banned on public.user_profiles(banned_at)
  where banned_at is not null;

-- ─── RPC: set_role (super_admin only) ────────────────────────────────────
create or replace function admin_set_role(target_id uuid, new_role user_role)
returns void as $$
declare
  caller_role user_role;
begin
  select role into caller_role from public.user_profiles where user_id = auth.uid();
  if caller_role is null or caller_role != 'super_admin' then
    raise exception 'Forbidden: only super_admin can change roles';
  end if;
  update public.user_profiles set role = new_role where user_id = target_id;
end;
$$ language plpgsql security definer;

-- ─── RPC: ban_user (admin atau super_admin) ──────────────────────────────
create or replace function admin_ban_user(target_id uuid, reason text)
returns void as $$
declare
  caller_role user_role;
  target_role user_role;
begin
  select role into caller_role from public.user_profiles where user_id = auth.uid();
  if caller_role not in ('admin', 'super_admin') then
    raise exception 'Forbidden';
  end if;
  -- Admin biasa tidak bisa ban super_admin atau admin lain
  select role into target_role from public.user_profiles where user_id = target_id;
  if caller_role = 'admin' and target_role in ('admin', 'super_admin') then
    raise exception 'Forbidden: admin cannot ban admin/super_admin';
  end if;
  update public.user_profiles
  set banned_at = now(), banned_reason = reason, banned_by = auth.uid()
  where user_id = target_id;
end;
$$ language plpgsql security definer;

-- ─── RPC: unban_user ─────────────────────────────────────────────────────
create or replace function admin_unban_user(target_id uuid)
returns void as $$
declare caller_role user_role;
begin
  select role into caller_role from public.user_profiles where user_id = auth.uid();
  if caller_role not in ('admin', 'super_admin') then
    raise exception 'Forbidden';
  end if;
  update public.user_profiles
  set banned_at = null, banned_reason = null, banned_by = null
  where user_id = target_id;
end;
$$ language plpgsql security definer;

-- ─── RPC: dashboard stats ────────────────────────────────────────────────
create or replace function admin_dashboard_stats()
returns table (
  total_users bigint,
  signups_today bigint,
  signups_week bigint,
  active_users_7d bigint,
  total_messages bigint,
  total_friendships bigint,
  banned_users bigint,
  admin_count bigint
) as $$
  select
    (select count(*) from public.user_profiles) as total_users,
    (select count(*) from public.user_profiles
       where created_at > now() - interval '1 day') as signups_today,
    (select count(*) from public.user_profiles
       where created_at > now() - interval '7 days') as signups_week,
    (select count(distinct user_id) from public.activity_events
       where created_at > now() - interval '7 days') as active_users_7d,
    coalesce((select count(*) from public.direct_messages), 0) as total_messages,
    (select count(*) from public.friendships where status = 'accepted') as total_friendships,
    (select count(*) from public.user_profiles where banned_at is not null) as banned_users,
    (select count(*) from public.user_profiles where role in ('admin', 'super_admin')) as admin_count;
$$ language sql security definer;

-- ─── RPC: list_users (admin only, paginated) ─────────────────────────────
create or replace function admin_list_users(
  p_query text default '',
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  user_id uuid,
  email text,
  username text,
  avatar_url text,
  role user_role,
  banned_at timestamptz,
  banned_reason text,
  created_at timestamptz
) as $$
declare caller_role user_role;
begin
  select up.role into caller_role from public.user_profiles up where up.user_id = auth.uid();
  if caller_role not in ('admin', 'super_admin') then
    raise exception 'Forbidden';
  end if;
  return query
  select up.user_id, u.email, up.username, up.avatar_url, up.role,
         up.banned_at, up.banned_reason, up.created_at
  from public.user_profiles up
  join auth.users u on u.id = up.user_id
  where p_query = '' OR up.username ilike '%' || p_query || '%' OR u.email ilike '%' || p_query || '%'
  order by up.created_at desc
  limit p_limit
  offset p_offset;
end;
$$ language plpgsql security definer;

-- ─── RPC: recent messages (moderation) ───────────────────────────────────
create or replace function admin_recent_messages(p_limit int default 100)
returns table (
  id uuid,
  sender_id uuid,
  sender_username text,
  recipient_id uuid,
  content text,
  created_at timestamptz
) as $$
declare caller_role user_role;
begin
  select role into caller_role from public.user_profiles where user_id = auth.uid();
  if caller_role not in ('admin', 'super_admin') then
    raise exception 'Forbidden';
  end if;
  return query
  select dm.id, dm.sender_id, up.username, dm.recipient_id, dm.content, dm.created_at
  from public.direct_messages dm
  left join public.user_profiles up on up.user_id = dm.sender_id
  order by dm.created_at desc
  limit p_limit;
end;
$$ language plpgsql security definer;

-- ─── RPC: delete message (admin/super_admin) ─────────────────────────────
create or replace function admin_delete_message(message_id uuid)
returns void as $$
declare caller_role user_role;
begin
  select role into caller_role from public.user_profiles where user_id = auth.uid();
  if caller_role not in ('admin', 'super_admin') then
    raise exception 'Forbidden';
  end if;
  delete from public.direct_messages where id = message_id;
end;
$$ language plpgsql security definer;
