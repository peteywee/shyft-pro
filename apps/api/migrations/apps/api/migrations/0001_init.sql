-- 0001_init.sql
create extension if not exists pgcrypto;

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  display_name text not null,
  role text not null check (role in ('worker','admin')),
  created_at timestamptz not null default now()
);

create table if not exists authenticators (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id),
  credential_id bytea not null unique,
  public_key bytea not null,
  counter bigint not null default 0,
  transports text[],
  attestation_fmt text,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create table if not exists sites (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  geofence jsonb,
  tz text not null,
  created_at timestamptz not null default now()
);

create table if not exists punches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id),
  site_id uuid references sites(id),
  type text not null check (type in ('IN','OUT')),
  ts_server timestamptz not null default now(),
  ts_device timestamptz,
  source text not null check (source in ('mobile','kiosk')),
  geo jsonb,
  risk_flags jsonb not null default '[]'::jsonb,
  idempotency_key text,
  signature bytea
);

create unique index if not exists punches_idem_uk
  on punches (user_id, idempotency_key)
  where idempotency_key is not null;

create table if not exists audit_log (
  id uuid primary key default gen_random_uuid(),
  actor uuid,
  event_type text not null,
  ts timestamptz not null default now(),
  payload_hash bytea not null,
  payload jsonb not null
);
