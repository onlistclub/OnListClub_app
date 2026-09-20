-- Atomic registration transaction: inserts into public.users and public.users_phones
-- Parameters:
--  p_user_id: UUID from auth.users
--  p_nome, p_cognome: text
--  p_email: text
--  p_data_nascita: date
--  p_telefono: text (normalized E.164)
--  p_country_iso: text (ISO alpha-2, e.g., 'IT')
-- Returns: JSON with inserted ids and flags
create or replace function public.register_user_transaction(
  p_user_id uuid,
  p_nome text,
  p_cognome text,
  p_email text,
  p_data_nascita date,
  p_telefono text,
  p_country_iso text
)
returns json
language plpgsql
security definer
as $$
declare
  v_is_adult boolean := false;
  v_users_id uuid := p_user_id;
  v_country_id uuid := null;
  v_now timestamp := now();
  v_has_iso boolean := false;
  v_has_code boolean := false;
  v_dial text := null;
  v_e164 text := null;
begin
  if p_nome is null or length(trim(p_nome)) = 0 then
    raise exception 'Nome obbligatorio';
  end if;
  if p_cognome is null or length(trim(p_cognome)) = 0 then
    raise exception 'Cognome obbligatorio';
  end if;
  if p_data_nascita is null then
    raise exception 'Data di nascita obbligatoria';
  end if;
  if p_telefono is null or length(trim(p_telefono)) < 7 then
    raise exception 'Telefono non valido';
  end if;

  v_is_adult := (date_part('year', age(current_date, p_data_nascita)) >= 18);

  select exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='countries' and column_name='iso'
  ) into v_has_iso;

  select exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='countries' and column_name='code'
  ) into v_has_code;

  if v_has_iso then
    select id, dial_code::text into v_country_id, v_dial
    from public.countries
    where upper(iso) = upper(p_country_iso)
    limit 1;
  elsif v_has_code then
    select id, dial_code::text into v_country_id, v_dial
    from public.countries
    where upper(code) = upper(p_country_iso)
    limit 1;
  else
    v_country_id := null;
  end if;

  -- Sanitize to E.164: remove spaces, ensure leading '+'
  v_e164 := replace(coalesce(p_telefono, ''), ' ', '');
  if v_e164 is null or v_e164 = '' then
    raise exception 'Telefono non valido';
  end if;
  if v_e164 !~ '^\+' then
    v_e164 := '+' || v_e164;
  end if;

  begin
    insert into public.users (id, nome, cognome, email, data_nascita, maggiorenne, created_at)
    values (v_users_id, p_nome, p_cognome, p_email, p_data_nascita, v_is_adult, v_now)
    on conflict (id) do update
      set nome = excluded.nome,
          cognome = excluded.cognome,
          email = excluded.email,
          data_nascita = excluded.data_nascita,
          maggiorenne = excluded.maggiorenne,
          updated_at = v_now;

    insert into public.users_phones (user_id, country_id, telefono, is_primary, is_verified, created_at)
    values (v_users_id, v_country_id, v_e164, true, false, v_now)
    on conflict (user_id, telefono) do update
      set country_id = excluded.country_id,
          is_primary = excluded.is_primary,
          is_verified = excluded.is_verified,
          updated_at = v_now;

    return json_build_object(
      'user_id', v_users_id,
      'country_id', v_country_id,
      'maggiorenne', v_is_adult,
      'status', 'ok'
    );
  exception when others then
    raise;
  end;
end;
$$;
