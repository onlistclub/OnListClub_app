-- Migration: store only national number digits in users_phones.telefono
-- 1) Strip '+' and non-digits from existing rows
update public.users_phones
set telefono = regexp_replace(telefono, '\D', '', 'g')
where telefono is not null;

-- 2) Ensure telefono contains only digits
alter table public.users_phones
  add constraint users_phones_telefono_digits_chk
  check (telefono ~ '^[0-9]+$');

-- 3) Unique constraint for user_id + telefono (avoid duplicates per user)
create unique index if not exists users_phones_user_id_tel_uq
  on public.users_phones(user_id, telefono);

-- 4) Optional: validate length using countries table if min/max columns exist; fallback 7..15
create or replace function public.validate_phone_length()
returns trigger
language plpgsql
as $$
declare
  v_min int := 7;
  v_max int := 15;
  v_has_min boolean := false;
  v_has_max boolean := false;
begin
  select exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='countries' and column_name='nsn_min_len'
  ) into v_has_min;
  select exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='countries' and column_name='nsn_max_len'
  ) into v_has_max;

  if v_has_min then
    select nsn_min_len into v_min from public.countries where id = NEW.country_id;
    if v_min is null then v_min := 7; end if;
  end if;
  if v_has_max then
    select nsn_max_len into v_max from public.countries where id = NEW.country_id;
    if v_max is null then v_max := 15; end if;
  end if;

  if NEW.telefono is null or NEW.telefono !~ '^[0-9]+$' then
    raise exception 'Telefono deve contenere solo cifre';
  end if;

  if length(NEW.telefono) < v_min or length(NEW.telefono) > v_max then
    raise exception 'Lunghezza numero non valida per il paese selezionato';
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_validate_phone_length on public.users_phones;
create trigger trg_validate_phone_length
before insert or update on public.users_phones
for each row execute function public.validate_phone_length();
