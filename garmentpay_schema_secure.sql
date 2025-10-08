-- ============================================================
-- GarmentPay Hub - Secure Auth + RLS Schema (Admin + Karyawan + Anonymous)
-- Idempotent: aman dijalankan berulang kali.
-- ============================================================

create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

do $$ begin create type user_role as enum ('admin','karyawan'); exception when duplicate_object then null; end $$;

create table if not exists workers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  role text check (role in ('Penjahit','Pemotong','Finishing','Admin')) default 'Penjahit',
  phone text,
  status text default 'Aktif',
  user_id uuid null references auth.users(id) on delete set null,
  created_at timestamptz default now()
);

create table if not exists work_logs (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid references workers(id) on delete cascade,
  item_name text not null,
  qty integer not null check (qty > 0),
  rate integer not null check (rate >= 0),
  work_date date default now(),
  created_at timestamptz default now()
);

create table if not exists advances (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid references workers(id) on delete cascade,
  amount integer not null check (amount > 0),
  note text,
  taken_at date default now(),
  created_at timestamptz default now()
);

create table if not exists payouts (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid references workers(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  gross integer not null,
  advances integer not null,
  net integer not null,
  created_at timestamptz default now()
);

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  role user_role not null default 'karyawan',
  worker_id uuid null references workers(id) on delete set null,
  created_at timestamptz default now()
);

create or replace function handle_new_user()
returns trigger as $$
begin
  insert into profiles (id, email, role)
  values (new.id, new.email, 'karyawan')
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function handle_new_user();

create or replace function handle_anon_user()
returns trigger as $$
begin
  if new.is_anonymous = true then
    insert into profiles (id, role)
    values (new.id, 'karyawan')
    on conflict (id) do nothing;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_anon_user_created on auth.users;
create trigger on_auth_anon_user_created
after insert on auth.users
for each row
when (new.is_anonymous = true)
execute function handle_anon_user();

alter table profiles enable row level security;
alter table workers  enable row level security;
alter table work_logs enable row level security;
alter table advances  enable row level security;
alter table payouts   enable row level security;

drop policy if exists profiles_admin_all on profiles;
drop policy if exists profiles_self_read on profiles;
drop policy if exists workers_admin_all on workers;
drop policy if exists workers_employee_self on workers;
drop policy if exists work_logs_admin_all on work_logs;
drop policy if exists work_logs_employee_read_own on work_logs;
drop policy if exists work_logs_employee_insert_own on work_logs;
drop policy if exists advances_admin_all on advances;
drop policy if exists advances_employee_read_own on advances;
drop policy if exists payouts_admin_all on payouts;
drop policy if exists payouts_employee_read_own on payouts;

create policy profiles_admin_all on profiles for all using (
  exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin')
) with check (
  exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin')
);

create policy profiles_self_read on profiles for select using (id = auth.uid());

create policy workers_admin_all on workers for all using (
  exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin')
) with check (
  exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin')
);

create policy workers_employee_self on workers for select using (
  exists (select 1 from profiles p where p.id = auth.uid() and p.worker_id = workers.id)
);

create policy work_logs_admin_all on work_logs for all using (
  exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin')
) with check (
  exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin')
);

create policy work_logs_employee_read_own on work_logs for select using (
  exists (select 1 from profiles p where p.id = auth.uid() and p.worker_id = work_logs.worker_id)
);

create policy work_logs_employee_insert_own on work_logs for insert with check (
  exists (select 1 from profiles p where p.id = auth.uid() and p.worker_id = work_logs.worker_id)
);

create policy advances_admin_all on advances for all using (
  exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin')
) with check (
  exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin')
);

create policy advances_employee_read_own on advances for select using (
  exists (select 1 from profiles p where p.id = auth.uid() and p.worker_id = advances.worker_id)
);

create policy payouts_admin_all on payouts for all using (
  exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin')
) with check (
  exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin')
);

create policy payouts_employee_read_own on payouts for select using (
  exists (select 1 from profiles p where p.id = auth.uid() and p.worker_id = payouts.worker_id)
);

create index if not exists idx_workers_user_id on workers(user_id);
create index if not exists idx_work_logs_worker on work_logs(worker_id, created_at);
create index if not exists idx_advances_worker on advances(worker_id, created_at);
create index if not exists idx_payouts_worker on payouts(worker_id, period_start, period_end);

-- Examples:
-- update profiles set role='admin' where email='owner@contoh.com';
-- update profiles set worker_id = (select id from workers where name='Budi') where id = 'UUID_USER_ANON_BUDI';
