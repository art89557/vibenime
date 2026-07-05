-- VibeNime banners bucket
-- ---------------------------------------------------------
-- Storage bucket untuk banner profile (1500×500). Mirror dari avatars
-- bucket — user upload di folder `{userId}/` mereka sendiri.

insert into storage.buckets (id, name, public)
values ('banners', 'banners', true)
on conflict (id) do nothing;

drop policy if exists "banners_user_upload" on storage.objects;
create policy "banners_user_upload"
  on storage.objects for insert
  with check (
    bucket_id = 'banners'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "banners_user_update" on storage.objects;
create policy "banners_user_update"
  on storage.objects for update
  using (
    bucket_id = 'banners'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "banners_user_delete" on storage.objects;
create policy "banners_user_delete"
  on storage.objects for delete
  using (
    bucket_id = 'banners'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "banners_public_read" on storage.objects;
create policy "banners_public_read"
  on storage.objects for select
  using (bucket_id = 'banners');
