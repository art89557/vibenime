-- VibeNime friendships
-- ---------------------------------------------------------
-- Tabel friendship antar user. Status: pending → accepted (atau blocked).
-- Pair unique — tidak bisa duplicate request.

create type friendship_status as enum ('pending', 'accepted', 'blocked');

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status friendship_status not null default 'pending',
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  constraint no_self_friend check (requester_id != recipient_id),
  constraint unique_pair unique (requester_id, recipient_id)
);

create index if not exists idx_friendships_recipient
  on public.friendships(recipient_id, status);
create index if not exists idx_friendships_requester
  on public.friendships(requester_id, status);

alter table public.friendships enable row level security;

drop policy if exists "friendships_read_own" on public.friendships;
create policy "friendships_read_own" on public.friendships for select
  using (auth.uid() = requester_id OR auth.uid() = recipient_id);

drop policy if exists "friendships_insert_own_request" on public.friendships;
create policy "friendships_insert_own_request" on public.friendships for insert
  with check (auth.uid() = requester_id);

drop policy if exists "friendships_update_as_recipient" on public.friendships;
create policy "friendships_update_as_recipient" on public.friendships for update
  using (auth.uid() = recipient_id OR auth.uid() = requester_id);

drop policy if exists "friendships_delete_own" on public.friendships;
create policy "friendships_delete_own" on public.friendships for delete
  using (auth.uid() = requester_id OR auth.uid() = recipient_id);

-- Realtime: enable supaya client subscribe perubahan friendship live
alter publication supabase_realtime add table public.friendships;

-- ─── Search users RPC ─────────────────────────────────────────────────────
-- auth.users tidak boleh diakses RLS langsung dari client.
-- Pakai SQL function `security definer` untuk search by username.

create or replace function search_users_by_username(query text)
returns table (id uuid, username text, avatar_url text, email text) as $$
  select u.id,
         coalesce(u.raw_user_meta_data->>'username', split_part(u.email, '@', 1)) as username,
         u.raw_user_meta_data->>'avatar_url' as avatar_url,
         u.email as email
  from auth.users u
  where (u.raw_user_meta_data->>'username') ilike '%' || query || '%'
     OR u.email ilike '%' || query || '%'
  limit 20;
$$ language sql security definer;

-- Function untuk resolve user profile by ID (untuk Friend list / DM partner)
create or replace function get_user_profile(target_id uuid)
returns table (
  id uuid,
  username text,
  avatar_url text,
  banner_url text,
  bio text,
  avatar_border text
) as $$
  select u.id,
         coalesce(u.raw_user_meta_data->>'username', split_part(u.email, '@', 1)) as username,
         u.raw_user_meta_data->>'avatar_url' as avatar_url,
         u.raw_user_meta_data->>'banner_url' as banner_url,
         u.raw_user_meta_data->>'bio' as bio,
         u.raw_user_meta_data->>'avatar_border' as avatar_border
  from auth.users u
  where u.id = target_id;
$$ language sql security definer;
