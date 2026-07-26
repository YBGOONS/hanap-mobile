-- HANAP — initial schema.
-- Run this once in Supabase Dashboard → SQL Editor → New query → paste → Run.
--
-- auth.users is managed by Supabase Auth itself (email/password, etc).
-- public.profiles is a 1:1 companion row holding app-specific fields
-- (role, location, skill, approval status) and is auto-created by a
-- trigger whenever someone signs up.

-- ── PROFILES ────────────────────────────────────────────────────────────

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null check (role in ('client', 'worker', 'admin')),
  first_name text not null,
  last_name text not null,
  email text not null,
  location text not null,
  phone text,
  primary_skill text, -- deprecated, superseded by `skills` below; kept (unused) rather than dropped to avoid a destructive migration
  skills text[], -- workers can have more than one; register screen writes a single-element array for now
  available boolean not null default true, -- worker's "open for jobs" toggle
  avatar_url text,
  nbi_clearance_path text,
  status text not null default 'active' check (status in ('pending', 'active', 'rejected', 'suspended')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- RLS policies narrow ROW access, but Postgres also needs the base table
-- grant before the `authenticated` role can touch it at all — tables made
-- via raw SQL (unlike the dashboard Table Editor) don't get this for free.
grant usage on schema public to authenticated;
grant select, update on public.profiles to authenticated;

-- Auto-create a profile row when someone signs up. The register screen
-- passes role/first_name/last_name/location/skills as auth "user metadata"
-- (the `data:` param of supabase.auth.signUp) — this trigger copies that
-- into the profiles table. Workers start 'pending' until an admin approves
-- them; clients start 'active' immediately.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, role, first_name, last_name, email, location, skills, status)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'role', 'client'),
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    new.email,
    coalesce(new.raw_user_meta_data ->> 'location', ''),
    case
      when new.raw_user_meta_data ? 'skills' then
        array(select jsonb_array_elements_text(new.raw_user_meta_data -> 'skills'))
      else null
    end,
    case when new.raw_user_meta_data ->> 'role' = 'worker' then 'pending' else 'active' end
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Prevent users from promoting themselves to admin or self-approving as a
-- worker by editing role/status directly — only an existing admin's update
-- is allowed to change those two columns. SQL Editor queries (current_user
-- = 'postgres') and service_role requests are always trusted — auth.uid()
-- is null outside of a real PostgREST request, so without this check the
-- SQL Editor itself would get blocked from approving workers.
--
-- Deliberately NOT `security definer` here: inside a security definer
-- function, current_user resolves to the function's OWNER (postgres, since
-- it was created from the SQL Editor), not the actual caller — that made
-- this check always true, i.e. no protection at all, for every caller
-- including regular end users. Plain security invoker keeps current_user
-- as the real caller's role.
create or replace function public.protect_profile_fields()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user not in ('postgres', 'service_role') then
    if not exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') then
      new.role := old.role;
      new.status := old.status;
    end if;
  end if;
  return new;
end;
$$;

create trigger protect_profile_fields_trigger
  before update on public.profiles
  for each row execute function public.protect_profile_fields();

-- Any logged-in user can see basic profile info (needed to show worker
-- names on jobs, etc). Everyone can edit their own row (role/status are
-- still locked down by the trigger above regardless of this policy).
create policy "profiles_select_authenticated"
  on public.profiles for select
  to authenticated
  using (true);

create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Admins can update ANY profile (approve/reject/suspend workers, etc).
-- protect_profile_fields_trigger still governs role/status specifically —
-- this policy just gets admins past profiles_update_own's "self only" rule.
create policy "profiles_admin_updates_any"
  on public.profiles for update
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- ── JOBS ────────────────────────────────────────────────────────────────

create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles (id) on delete cascade,
  worker_id uuid references public.profiles (id) on delete set null,
  category text not null,
  description text not null,
  budget numeric(10, 2),
  location text not null,
  scheduled_date date,
  status text not null default 'open' check (status in ('open', 'accepted', 'arrived', 'in_progress', 'completed', 'cancelled')),
  cancel_reason text, -- set when a worker backs out via cancel_job() below
  cancelled_at timestamptz,
  -- Payment tracking is a separate column from `status` above (job progress
  -- vs money movement are different concerns) — no real payment gateway
  -- behind this yet, so there's no 'escrowed' state, just a flat request/
  -- resolve flow. See mark_job_paid/request_refund/resolve_refund below.
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid', 'paid', 'refund_requested', 'refunded')),
  refund_reason text,
  refund_requested_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.jobs enable row level security;
grant select, insert, update, delete on public.jobs to authenticated;
create index jobs_status_idx on public.jobs (status);
create index jobs_client_id_idx on public.jobs (client_id);
create index jobs_worker_id_idx on public.jobs (worker_id);

-- Open jobs are visible to anyone logged in (workers browsing); a job's own
-- client/worker can always see it regardless of status.
create policy "jobs_select"
  on public.jobs for select
  to authenticated
  using (status = 'open' or client_id = auth.uid() or worker_id = auth.uid());

-- Admin needs to see every job regardless of status/ownership (Jobs tab,
-- Dashboard/Reports aggregates) — same gap as profiles_admin_updates_any.
create policy "jobs_admin_select_all"
  on public.jobs for select
  to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

create policy "jobs_insert_own_as_client"
  on public.jobs for insert
  to authenticated
  with check (
    client_id = auth.uid()
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'client')
  );

create policy "jobs_client_updates_own_open_job"
  on public.jobs for update
  to authenticated
  using (client_id = auth.uid() and status = 'open')
  with check (client_id = auth.uid());

create policy "jobs_client_deletes_own_open_job"
  on public.jobs for delete
  to authenticated
  using (client_id = auth.uid() and status = 'open');

-- ── NOTIFICATIONS ───────────────────────────────────────────────────────
-- System-generated, one row per recipient per event (job accepted, status
-- changed, paid, refund requested/resolved, etc). Defined here (ahead of
-- the RPCs below) since those RPCs insert into it. No insert policy for
-- authenticated — only the security definer RPCs create rows.

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text,
  job_id uuid references public.jobs (id) on delete cascade,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.notifications enable row level security;
grant select, update on public.notifications to authenticated;
create index notifications_user_id_idx on public.notifications (user_id);

create policy "notifications_select_own"
  on public.notifications for select
  to authenticated
  using (user_id = auth.uid());

create policy "notifications_update_own"
  on public.notifications for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Status transitions (accept / start / complete / cancel) go through the
-- RPC functions below instead of raw UPDATEs — much easier to reason about
-- correctly than stacking several overlapping RLS UPDATE policies. Each
-- also drops a notification for the other party.

create or replace function public.accept_job(job_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  j record;
begin
  update public.jobs
  set worker_id = auth.uid(), status = 'accepted'
  where id = job_id
    and status = 'open'
    and exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'worker' and status = 'active'
    )
  returning * into j;

  if not found then
    raise exception 'Job is no longer available.';
  end if;

  insert into public.notifications (user_id, title, body, job_id)
  values (j.client_id, 'Worker accepted your job', 'Someone accepted your "' || j.category || '" job.', j.id);
end;
$$;

create or replace function public.update_job_status(job_id uuid, new_status text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  j record;
begin
  if new_status not in ('arrived', 'in_progress', 'completed', 'cancelled') then
    raise exception 'Invalid status: %', new_status;
  end if;

  update public.jobs
  set status = new_status
  where id = job_id and worker_id = auth.uid()
  returning * into j;

  if not found then
    raise exception 'Not authorized, or job not found.';
  end if;

  insert into public.notifications (user_id, title, body, job_id)
  values (
    j.client_id,
    case new_status
      when 'arrived' then 'Your worker has arrived'
      when 'in_progress' then 'Your job has started'
      when 'completed' then 'Your job is complete'
      else 'Job status updated'
    end,
    case new_status
      when 'arrived' then 'Your worker has arrived at the job location for "' || j.category || '".'
      else 'Your "' || j.category || '" job is now ' || new_status || '.'
    end,
    j.id
  );
end;
$$;

-- Worker backs out of a job they already accepted — returns it to the open
-- pool for other workers instead of leaving the client stuck.
create or replace function public.cancel_job(job_id uuid, reason text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  j record;
begin
  update public.jobs
  set status = 'open', worker_id = null, cancel_reason = reason, cancelled_at = now()
  where id = job_id and worker_id = auth.uid() and status in ('accepted', 'arrived', 'in_progress')
  returning * into j;

  if not found then
    raise exception 'Not authorized, or job cannot be cancelled right now.';
  end if;

  insert into public.notifications (user_id, title, body, job_id)
  values (j.client_id, 'Worker backed out', 'The worker backed out of your "' || j.category || '" job. It''s back in the open pool.', j.id);
end;
$$;

-- Client cancels a job that no worker has accepted yet. Once a worker is
-- assigned, the client can no longer unilaterally cancel (see cancel_job
-- above for the worker's own backing-out path) — this is deliberately the
-- only cancellation route open to a client.
create or replace function public.cancel_open_job(job_id uuid, reason text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  j record;
begin
  update public.jobs
  set status = 'cancelled', cancel_reason = reason, cancelled_at = now()
  where id = job_id and client_id = auth.uid() and status = 'open'
  returning * into j;

  if not found then
    raise exception 'Job cannot be cancelled right now.';
  end if;
end;
$$;

-- Posting a job also notifies every active, available worker whose skills
-- include the job's category — client-side inserting notifications isn't
-- possible (notifications has no insert policy for authenticated, only
-- security definer RPCs write to it), so job creation itself moves into
-- an RPC instead of a raw table insert.
create or replace function public.post_job(
  category text,
  description text,
  budget numeric,
  location text,
  scheduled_date date
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  new_job_id uuid;
  w record;
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'client') then
    raise exception 'Only clients can post jobs.';
  end if;

  insert into public.jobs (client_id, category, description, budget, location, scheduled_date)
  values (auth.uid(), category, description, budget, location, scheduled_date)
  returning id into new_job_id;

  for w in
    select id from public.profiles
    where role = 'worker' and status = 'active' and available = true
      and skills is not null and category = any(skills)
  loop
    insert into public.notifications (user_id, title, body, job_id)
    values (w.id, 'New job available', 'A new "' || category || '" job was posted in ' || location || '.', new_job_id);
  end loop;

  return new_job_id;
end;
$$;

grant execute on function public.accept_job(uuid) to authenticated;
grant execute on function public.update_job_status(uuid, text) to authenticated;
grant execute on function public.cancel_job(uuid, text) to authenticated;
grant execute on function public.cancel_open_job(uuid, text) to authenticated;
grant execute on function public.post_job(text, text, numeric, text, date) to authenticated;

-- ── MESSAGES ────────────────────────────────────────────────────────────
-- One thread per job — the two participants are just jobs.client_id and
-- jobs.worker_id, so there's no separate "conversations" table. Messaging
-- becomes possible the moment a job has a worker (worker_id set), and stays
-- open regardless of job status afterward (follow-up questions post-
-- completion are still legitimate). Realtime enabled so ChatScreen can
-- stream new messages instead of polling.

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.messages enable row level security;
grant select, insert, update on public.messages to authenticated;
create index messages_job_created_idx on public.messages (job_id, created_at);

create policy "messages_select_participants"
  on public.messages for select
  to authenticated
  using (exists (select 1 from public.jobs where id = job_id and (client_id = auth.uid() or worker_id = auth.uid())));

create policy "messages_insert_participants"
  on public.messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and exists (select 1 from public.jobs where id = job_id and (client_id = auth.uid() or worker_id = auth.uid()))
  );

create policy "messages_update_participants"
  on public.messages for update
  to authenticated
  using (exists (select 1 from public.jobs where id = job_id and (client_id = auth.uid() or worker_id = auth.uid())))
  with check (exists (select 1 from public.jobs where id = job_id and (client_id = auth.uid() or worker_id = auth.uid())));

alter publication supabase_realtime add table public.messages;

-- ── TRANSACTIONS (payments/refunds) ────────────────────────────────────
-- One row per money-movement event — this is what the Admin Transactions
-- tab and the Client/Worker payment-history views read from. All writes
-- happen through the RPCs below (security definer), never a direct insert
-- policy, same approach as the job-status RPCs above.

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs (id) on delete cascade,
  client_id uuid not null references public.profiles (id) on delete cascade,
  worker_id uuid not null references public.profiles (id) on delete cascade,
  amount numeric(10, 2) not null,
  type text not null check (type in ('payment', 'refund')),
  created_at timestamptz not null default now()
);

alter table public.transactions enable row level security;
grant select on public.transactions to authenticated;
create index transactions_job_id_idx on public.transactions (job_id);

create policy "transactions_select_own_or_admin"
  on public.transactions for select
  to authenticated
  using (
    client_id = auth.uid()
    or worker_id = auth.uid()
    or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- Client pays for a completed job.
create or replace function public.mark_job_paid(job_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  j record;
begin
  select * into j from public.jobs
  where id = job_id and client_id = auth.uid() and status = 'completed' and payment_status = 'unpaid';

  if not found then
    raise exception 'Job is not eligible for payment right now.';
  end if;

  update public.jobs set payment_status = 'paid' where id = job_id;
  insert into public.transactions (job_id, client_id, worker_id, amount, type)
  values (j.id, j.client_id, j.worker_id, coalesce(j.budget, 0), 'payment');

  insert into public.notifications (user_id, title, body, job_id)
  values (j.worker_id, 'You got paid', 'You were paid ₱' || coalesce(j.budget, 0)::text || ' for "' || j.category || '".', j.id);
end;
$$;

-- Client requests a refund on a job they already paid for.
create or replace function public.request_refund(job_id uuid, reason text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  j record;
begin
  update public.jobs
  set payment_status = 'refund_requested', refund_reason = reason, refund_requested_at = now()
  where id = job_id and client_id = auth.uid() and payment_status = 'paid'
  returning * into j;

  if not found then
    raise exception 'Not authorized, or job is not eligible for a refund request.';
  end if;

  insert into public.notifications (user_id, title, body, job_id)
  values (j.worker_id, 'Refund requested', 'The client requested a refund for "' || j.category || '".', j.id);
end;
$$;

-- Admin approves or denies a pending refund request.
create or replace function public.resolve_refund(job_id uuid, approve boolean)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  j record;
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  select * into j from public.jobs where id = job_id and payment_status = 'refund_requested';
  if not found then
    raise exception 'Job has no pending refund request.';
  end if;

  if approve then
    update public.jobs set payment_status = 'refunded' where id = job_id;
    insert into public.transactions (job_id, client_id, worker_id, amount, type)
    values (j.id, j.client_id, j.worker_id, coalesce(j.budget, 0), 'refund');

    insert into public.notifications (user_id, title, body, job_id)
    values (j.client_id, 'Refund approved', 'Your refund for "' || j.category || '" was approved.', j.id);
  else
    update public.jobs set payment_status = 'paid' where id = job_id;

    insert into public.notifications (user_id, title, body, job_id)
    values (j.client_id, 'Refund denied', 'Your refund request for "' || j.category || '" was denied.', j.id);
  end if;
end;
$$;

grant execute on function public.mark_job_paid(uuid) to authenticated;
grant execute on function public.request_refund(uuid, text) to authenticated;
grant execute on function public.resolve_refund(uuid, boolean) to authenticated;

-- ── SCHEDULED JOBS (pg_cron) ────────────────────────────────────────────
-- Two background sweeps: auto-cancel open jobs nobody accepted by their
-- scheduled date, and a once-daily reminder for jobs happening tomorrow.
-- These are called only by pg_cron (as the role that ran this migration,
-- typically postgres), never by client code — no grant to authenticated.

create extension if not exists pg_cron with schema extensions;

create or replace function public.auto_expire_open_jobs()
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  j record;
begin
  for j in
    update public.jobs
    set status = 'cancelled',
        cancel_reason = 'Automatically cancelled — no worker accepted it before the scheduled date.',
        cancelled_at = now()
    where status = 'open' and scheduled_date is not null and scheduled_date < current_date
    returning *
  loop
    insert into public.notifications (user_id, title, body, job_id)
    values (j.client_id, 'Job auto-cancelled', 'Your "' || j.category || '" job was cancelled — no worker accepted it before the scheduled date.', j.id);
  end loop;
end;
$$;

create or replace function public.send_job_reminders()
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  j record;
begin
  for j in
    select * from public.jobs
    where status in ('accepted', 'in_progress') and scheduled_date = current_date + 1
  loop
    insert into public.notifications (user_id, title, body, job_id)
    values (j.client_id, 'Job reminder', 'Your "' || j.category || '" job is scheduled for tomorrow.', j.id);

    insert into public.notifications (user_id, title, body, job_id)
    values (j.worker_id, 'Job reminder', 'Your "' || j.category || '" job is scheduled for tomorrow.', j.id);
  end loop;
end;
$$;

-- Postgres grants EXECUTE to PUBLIC on new functions by default — revoke it
-- so only postgres (i.e. pg_cron, which runs as the scheduling role) can
-- call these, not any logged-in client/worker via the REST API.
revoke execute on function public.auto_expire_open_jobs() from public;
revoke execute on function public.send_job_reminders() from public;

select cron.schedule('auto-expire-open-jobs', '*/30 * * * *', $$select public.auto_expire_open_jobs()$$);
select cron.schedule('send-job-reminders', '0 0 * * *', $$select public.send_job_reminders()$$);

-- ── STORAGE: NBI clearance uploads ─────────────────────────────────────
-- Private bucket. Files are stored as `{user_id}/<filename>` — the folder
-- name IS the uploader's auth id, which is what these policies check.

insert into storage.buckets (id, name, public)
values ('nbi-clearance', 'nbi-clearance', false)
on conflict (id) do nothing;

create policy "nbi_upload_own_folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'nbi-clearance'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "nbi_read_own_file"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'nbi-clearance'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "nbi_admin_reads_all"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'nbi-clearance'
    and exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- ── STORAGE: profile avatars ────────────────────────────────────────────
-- Public bucket (unlike nbi-clearance) — avatars are meant to be seen by
-- other users (e.g. a client viewing a worker's profile), so files are
-- served straight from the public URL with no signed-URL step needed.
-- Same `{user_id}/<filename>` folder convention for the write policies.

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "avatars_upload_own_folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars_update_own_folder"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
