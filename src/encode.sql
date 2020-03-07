create or replace function is_nan(float8)
returns boolean language sql immutable
as $function$
  select $1 = double precision 'NaN'
$function$;

create or replace function is_negative_zero(float8)
returns boolean language sql immutable
as $function$
  select $1::text = '-0'
$function$;
--
-- float_to_bytea adapted from https://github.com/feross/ieee754
--
create or replace function float_to_bytea(value float8, isLittleEndian boolean)
returns bytea language plpgsql
as $function$
declare
  m bigint;
  numeric_e bigint;
  _pack bytea := E'\\313        '::bytea;
  mlen int := 52;
  elen int := 64 - mlen - 1;
  emax int := (1 << elen) - 1;
  ebias int := emax >> 1;
  rt numeric := case when mlen = 23 then power(2, -24) - power(2, -77) else 0 end;
  i int := case when isLittleEndian then 0 else  7 end;
  d int := case when isLittleEndian then 1 else -1 end;
  s int := case when value < 0 OR is_negative_zero(value) then 1 else 0 end;
  e int;
  c float8;
begin
  value := abs(value);

  if is_nan(value) OR value = 'infinity'::float8
  then
    m := case when is_nan(value) then 1 else 0 end;
    e := emax;
  else
    e := floor(ln(value) / ln(2));
    c := power(2, -e);

    if (value * c) < 1 then
      e := e - 1;
      c := c * 2;
    end if;

    if (e + ebias) >= 1 then
      value := value + (rt / c);
    else
      value := value + (rt * power(2, (1 - ebias)));
    end if;

    if (value * c) >= 2 then
      e := e + 1;
      c := c / 2;
    end if;

    if (e + ebias) >= emax then
      m = 0;
      e = emax;
    elsif (e + ebias) >= 1 then
      m = (((value * c) - 1) * power(2, mlen))::bigint;
      e = e + ebias;
    else
      m = value * power(2, (eBias - 1)) * power(2, mlen);
      e = 0;
    end if;
  end if;

  loop
    exit when mlen < 8;
    _pack := set_byte(_pack, 1 + i, (m::bigint & 255)::int);
    i := i + d;
    m := m / 256;
    mlen := mlen - 8;
  end loop;

  numeric_e = (e << mlen)::bigint | trunc(m)::bigint;
  elen := elen + mlen;

  loop
    exit when elen <= 0;
    _pack := set_byte(_pack, 1 + i, (numeric_e & 255)::int);
    i := i + d;
    numeric_e := numeric_e / 256;
    elen := elen - 8;
  end loop;

  _pack := set_byte(_pack, 1 + i - d, get_byte(_pack, 1 + i - d) | trunc(s * 128)::int);
  return _pack;
end;
$function$;

create or replace function msgpack_encode(_data jsonb) returns bytea language plpgsql
as $function$
declare _size integer;
declare _key text;
declare _pack bytea;
declare _chunk bytea;
declare _numeric numeric;
declare _item jsonb;
begin

  case jsonb_typeof(_data)
    when 'object' then
      -- Get count of items in object
      select count(jsonb_object_keys) into _size from jsonb_object_keys(_data);

      if _size < 16 then
        _pack = set_byte(E' '::bytea, 0, (128::bit(8) | _size::bit(8))::integer);
      elsif _size < 2 ^ 16 then
        _pack = E'\\336'::bytea
          || set_byte(E' '::bytea, 0, _size >> 8)
          || set_byte(E' '::bytea, 0, _size);
      elsif _size < 2 ^ 32 then
        _pack = E'\\337'::bytea
          || set_byte(E' '::bytea, 0, _size >> 24)
          || set_byte(E' '::bytea, 0, _size >> 16)
          || set_byte(E' '::bytea, 0, _size >> 8)
          || set_byte(E' '::bytea, 0, _size);
      else
        raise exception 'Maximum number of keys exceeded.';
      end if;
    
      -- Process items
      for _key in select jsonb_object_keys from jsonb_object_keys(_data) loop
        _pack = _pack || public.msgpack_encode(to_jsonb(_key)) || public.msgpack_encode(_data->_key);
      end loop;
    
    when 'array' then
      select jsonb_array_length into _size from jsonb_array_length(_data);

      if _size < 16 then
        _pack = set_byte(E' '::bytea, 0, (144::bit(8) | _size::bit(8))::integer);
      elsif _size < 2 ^ 16 then
        _pack = E'\\334'::bytea
          || set_byte(E' '::bytea, 0, _size >> 8)
          || set_byte(E' '::bytea, 0, _size);
      elsif _size < 2 ^ 32 then
        _pack = E'\\335'::bytea
          || set_byte(E' '::bytea, 0, _size >> 24)
          || set_byte(E' '::bytea, 0, _size >> 16)
          || set_byte(E' '::bytea, 0, _size >> 8)
          || set_byte(E' '::bytea, 0, _size);
      else
        raise exception 'Maximum number of items exceeded.';
      end if;
    
      -- Process items
      for _item in select value from jsonb_array_elements(_data) loop
        _pack = _pack || public.msgpack_encode(_item);
      end loop;
    
    when 'number' then
      _numeric = (_data#>>'{}')::numeric;
      if _numeric % 1 != 0 then
        -- treat all floats as 64-bit floats
        _pack = float_to_bytea(_numeric, false);  
      elsif _numeric > 0 then
        -- Integer
        if _numeric < 2 ^ 7 then
          _pack = set_byte(E' '::bytea, 0, _numeric::integer);
        elsif _numeric < 2 ^ 8 then
          _pack = E'\\314'::bytea
            || set_byte(E' '::bytea, 0, _numeric::integer);
        elsif _numeric < 2 ^ 15 then
          _pack = E'\\315'::bytea
            || set_byte(E' '::bytea, 0, (_numeric::integer >> 8) & 255)
            || set_byte(E' '::bytea, 0, _numeric::integer & 255);
        elsif _numeric < 2 ^ 31 then
          _pack = E'\\316'::bytea
            || set_byte(E' '::bytea, 0, (_numeric::integer >> 24) & 255)
            || set_byte(E' '::bytea, 0, (_numeric::integer >> 16) & 255)
            || set_byte(E' '::bytea, 0, (_numeric::integer >> 8) & 255)
            || set_byte(E' '::bytea, 0, _numeric::integer & 255);
        elsif _numeric < 2 ^ 63 then
          _pack = E'\\317'::bytea
            || set_byte(E' '::bytea, 0, ((_numeric::bigint >> 56) & 255)::integer)
            || set_byte(E' '::bytea, 0, ((_numeric::bigint >> 48) & 255)::integer)
            || set_byte(E' '::bytea, 0, ((_numeric::bigint >> 40) & 255)::integer)
            || set_byte(E' '::bytea, 0, ((_numeric::bigint >> 32) & 255)::integer)
            || set_byte(E' '::bytea, 0, ((_numeric::bigint >> 24) & 255)::integer)
            || set_byte(E' '::bytea, 0, ((_numeric::bigint >> 16) & 255)::integer)
            || set_byte(E' '::bytea, 0, ((_numeric::bigint >> 8) & 255)::integer)
            || set_byte(E' '::bytea, 0, (_numeric::bigint & 255)::integer);
        else
          raise exception 'Integer out of range.';
        end if;
      else
        if _numeric >= -2 ^ 5 then
          _pack = set_byte(E' '::bytea, 0, _numeric::integer);
        elsif _numeric >= -2 ^ 7 then
          _pack = E'\\320'::bytea
            || set_byte(E' '::bytea, 0, _numeric::integer);
        elsif _numeric >= -2 ^ 15 then
          _pack = E'\\321'::bytea
            || set_byte(E' '::bytea, 0, (_numeric::integer >> 8) & 255)
            || set_byte(E' '::bytea, 0, _numeric::integer & 255);
        elsif _numeric >= -2 ^ 31 then
          _pack = E'\\322'::bytea
            || set_byte(E' '::bytea, 0, (_numeric::integer >> 24) & 255)
            || set_byte(E' '::bytea, 0, (_numeric::integer >> 16) & 255)
            || set_byte(E' '::bytea, 0, (_numeric::integer >> 8) & 255)
            || set_byte(E' '::bytea, 0, _numeric::integer & 255);
        elsif _numeric >= -2 ^ 63 then
          _pack = E'\\323'::bytea
            || set_byte(E' '::bytea, 0, ((_numeric::bigint >> 56) & 255)::integer)
            || set_byte(E' '::bytea, 0, ((_numeric::bigint >> 48) & 255)::integer)
            || set_byte(E' '::bytea, 0, ((_numeric::bigint >> 40) & 255)::integer)
            || set_byte(E' '::bytea, 0, ((_numeric::bigint >> 32) & 255)::integer)
            || set_byte(E' '::bytea, 0, ((_numeric::bigint >> 24) & 255)::integer)
            || set_byte(E' '::bytea, 0, ((_numeric::bigint >> 16) & 255)::integer)
            || set_byte(E' '::bytea, 0, ((_numeric::bigint >> 8) & 255)::integer)
            || set_byte(E' '::bytea, 0, (_numeric::bigint & 255)::integer);
        else
          raise exception 'Integer out of range.';
        end if;
      end if;
    
    when 'string' then
      _chunk = convert_to(_data#>>'{}', 'utf8');
      _size = octet_length(_chunk);
      
      if _size <= 31 then
        _pack = set_byte(E' '::bytea, 0, ((160)::bit(8) | (_size)::bit(8))::integer);
      elsif _size <= (2 ^ 8) - 1 then
        _pack = E'\\331'::bytea || set_byte(E' '::bytea, 0, _size);
      elsif _size <= (2 ^ 16) - 1 then
        _pack = E'\\332'::bytea
          || set_byte(E' '::bytea, 0, _size >> 8)
          || set_byte(E' '::bytea, 0, _size);
      elsif _size <= (2 ^ 32) - 1 then
        _pack = E'\\333'::bytea
          || set_byte(E' '::bytea, 0, _size >> 24)
          || set_byte(E' '::bytea, 0, _size >> 16)
          || set_byte(E' '::bytea, 0, _size >> 8)
          || set_byte(E' '::bytea, 0, _size);
      else
        raise exception 'String is too long.';
      end if;
      
      _pack = _pack || _chunk;
  
    when 'boolean' then
      _pack = case _data::text when 'false' then E'\\302'::bytea else E'\\303'::bytea end;

    when 'null' then
      _pack = E'\\300'::bytea;
    
    else
      raise exception '% not implemented yet', jsonb_typeof(_data);
  end case;

  return _pack;

end;
$function$
