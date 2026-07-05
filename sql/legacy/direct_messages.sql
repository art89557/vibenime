-- VibeNime direct_messages
-- ---------------------------------------------------------
-- 1-on-1 chat antar friend. Realtime via Supabase publication.

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 2000),
  read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint dm_no_self check (sender_id != recipient_id)
);

create index if not exists idx_dm_conversation
  on public.direct_messages(
    least(sender_id, recipient_id),
    greatest(sender_id, recipient_id),
    created_at desc
  );

alter table public.direct_messages enable row level security;

-- Read: hanya sender atau recipient — DAN harus accepted friend.
drop policy if exists "dm_read_own" on public.direct_messages;
create policy "dm_read_own" on public.direct_messages for select
  using (
    (auth.uid() = sender_id OR auth.uid() = recipient_id)
    AND exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
      AND (
        (f.requester_id = auth.uid()
         AND f.recipient_id = (
           case when direct_messages.sender_id = auth.uid()
                then direct_messages.recipient_id
                else direct_messages.sender_id end))
        OR (f.recipient_id = auth.uid()
         AND f.requester_id = (
           case when direct_messages.sender_id = auth.uid()
                then direct_messages.recipient_id
                else direct_messages.sender_id end))
      )
    )
  );

-- Insert: harus sender = self AND friend with recipient.
drop policy if exists "dm_send_if_friend" on public.direct_messages;
create policy "dm_send_if_friend" on public.direct_messages for insert
  with check (
    auth.uid() = sender_id
    AND exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
      AND (
        (f.requester_id = auth.uid() AND f.recipient_id = direct_messages.recipient_id)
        OR (f.recipient_id = auth.uid() AND f.requester_id = direct_messages.recipient_id)
      )
    )
  );

-- Update: hanya recipient yang boleh set read_at.
drop policy if exists "dm_mark_read_as_recipient" on public.direct_messages;
create policy "dm_mark_read_as_recipient" on public.direct_messages for update
  using (auth.uid() = recipient_id);

-- Realtime channel untuk DM live chat
alter publication supabase_realtime add table public.direct_messages;
