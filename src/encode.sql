create or replace function msgpack_array(_data jsonb) returns bytea language plpgsql
as $function$
declare _size integer;
declare _item jsonb;
declare _pack bytea;
begin
		-- Get count of items in object
		select jsonb_array_length into _size from jsonb_array_length(_data);

		if _size < 16 then
			_pack := set_byte(E' '::bytea, 0, (144::bit(8) | _size::bit(8))::integer);
		elsif _size < 2 ^ 16 then
			_pack := E'\\334'::bytea
				|| set_byte(E' '::bytea, 0, _size >> 8)
				|| set_byte(E' '::bytea, 0, _size);
		elsif _size < 2 ^ 32 then
			_pack := E'\\335'::bytea
				|| set_byte(E' '::bytea, 0, _size >> 24)
				|| set_byte(E' '::bytea, 0, _size >> 16)
				|| set_byte(E' '::bytea, 0, _size >> 8)
				|| set_byte(E' '::bytea, 0, _size);
		else
			raise exception 'Maximum number of items exceeded.';
		end if;

		-- Process items
		for _item in select value from jsonb_array_elements(_data) loop
			_pack := _pack || public.msgpack_encode(_item);
		end loop;

		return _pack;
end;
$function$;

create or replace function msgpack_boolean(_data boolean) returns bytea language sql
as $function$
	SELECT case when _data then E'\\302'::bytea else E'\\303'::bytea end
$function$;

--
-- msgpack_float adapted from https://github.com/feross/ieee754
--
create or replace function msgpack_float(value float8, isLittleEndian boolean)
returns bytea language plpgsql
as $function$
declare
	m bigint;
	numeric_e bigint;
	_pack bytea := E'\\313				'::bytea;
	mlen int := 52;
	elen int := 64 - mlen - 1;
	emax int := (1 << elen) - 1;
	ebias int := emax >> 1;
	rt numeric := case when mlen = 23 then power(2, -24) - power(2, -77) else 0 end;
	i int := case when isLittleEndian then 0 else	7 end;
	d int := case when isLittleEndian then 1 else -1 end;
	s int := case when value < 0 OR (value::text = '-0') then 1 else 0 end;
	e int;
	c float8;
begin
	value := abs(value);

	if (value = double precision 'NaN') OR value = 'infinity'::float8
	then
		m := case when (value = double precision 'NaN') then 1 else 0 end;
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

create or replace function msgpack_integer(_numeric numeric) returns bytea language plpgsql
as $function$
begin
	if _numeric > 0 then
		if _numeric < 2 ^ 7 then
			return set_byte(E' '::bytea, 0, _numeric::integer);
		elsif _numeric < 2 ^ 8 then
			return E'\\314'::bytea
				|| set_byte(E' '::bytea, 0, _numeric::integer);
		elsif _numeric < 2 ^ 16 then
			return E'\\315'::bytea
				|| set_byte(E' '::bytea, 0, (_numeric::integer >> 8) & 255)
				|| set_byte(E' '::bytea, 0, _numeric::integer & 255);
		elsif _numeric < 2 ^ 32 then
			return E'\\316'::bytea
				|| set_byte(E' '::bytea, 0, (_numeric::integer >> 24) & 255)
				|| set_byte(E' '::bytea, 0, (_numeric::integer >> 16) & 255)
				|| set_byte(E' '::bytea, 0, (_numeric::integer >> 8) & 255)
				|| set_byte(E' '::bytea, 0, _numeric::integer & 255);
		elsif _numeric < 2 ^ 64 then
			return E'\\317'::bytea
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
			return set_byte(E' '::bytea, 0, _numeric::integer);
		elsif _numeric >= -2 ^ 7 then
			return E'\\320'::bytea
				|| set_byte(E' '::bytea, 0, _numeric::integer);
		elsif _numeric >= -2 ^ 15 then
			return E'\\321'::bytea
				|| set_byte(E' '::bytea, 0, (_numeric::integer >> 8) & 255)
				|| set_byte(E' '::bytea, 0, _numeric::integer & 255);
		elsif _numeric >= -2 ^ 31 then
			return E'\\322'::bytea
				|| set_byte(E' '::bytea, 0, (_numeric::integer >> 24) & 255)
				|| set_byte(E' '::bytea, 0, (_numeric::integer >> 16) & 255)
				|| set_byte(E' '::bytea, 0, (_numeric::integer >> 8) & 255)
				|| set_byte(E' '::bytea, 0, _numeric::integer & 255);
		elsif _numeric >= -2 ^ 63 then
			return E'\\323'::bytea
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
end;
$function$;

create or replace function msgpack_object(_data jsonb) returns bytea language plpgsql
as $function$
declare _size integer;
declare _key text;
declare _pack bytea;
begin
		-- Get count of items in object
		select count(jsonb_object_keys) into _size from jsonb_object_keys(_data);

		if _size < 16 then
			_pack := set_byte(E' '::bytea, 0, (128::bit(8) | _size::bit(8))::integer);
		elsif _size < 2 ^ 16 then
			_pack := E'\\336'::bytea
				|| set_byte(E' '::bytea, 0, _size >> 8)
				|| set_byte(E' '::bytea, 0, _size);
		elsif _size < 2 ^ 32 then
			_pack := E'\\337'::bytea
				|| set_byte(E' '::bytea, 0, _size >> 24)
				|| set_byte(E' '::bytea, 0, _size >> 16)
				|| set_byte(E' '::bytea, 0, _size >> 8)
				|| set_byte(E' '::bytea, 0, _size);
		else
			raise exception 'Maximum number of keys exceeded.';
		end if;

		-- Process items
		for _key in select jsonb_object_keys from jsonb_object_keys(_data) loop
			_pack := _pack || public.msgpack_encode(to_jsonb(_key)) || public.msgpack_encode(_data->_key);
		end loop;

		return _pack;
end;
$function$;

create or replace function msgpack_text(_data jsonb) returns bytea language plpgsql
as $function$
declare _size integer;
declare _pack bytea;
declare _chunk bytea;
begin
	_chunk = convert_to(_data#>>'{}', 'utf8');
	_size = octet_length(_chunk);
	
	if _size <= 31 then
		_pack := set_byte(E' '::bytea, 0, ((160)::bit(8) | (_size)::bit(8))::integer);
	elsif _size <= (2 ^ 8) - 1 then
		_pack := E'\\331'::bytea || set_byte(E' '::bytea, 0, _size);
	elsif _size <= (2 ^ 16) - 1 then
		_pack := E'\\332'::bytea
			|| set_byte(E' '::bytea, 0, _size >> 8)
			|| set_byte(E' '::bytea, 0, _size);
	elsif _size <= (2 ^ 32) - 1 then
		_pack := E'\\333'::bytea
			|| set_byte(E' '::bytea, 0, _size >> 24)
			|| set_byte(E' '::bytea, 0, _size >> 16)
			|| set_byte(E' '::bytea, 0, _size >> 8)
			|| set_byte(E' '::bytea, 0, _size);
	else
		raise exception 'String is too long.';
	end if;
	
	return _pack || _chunk;
end;
$function$;

create or replace function msgpack_encode(_data jsonb) returns bytea language plpgsql
as $function$
declare _pack bytea;
begin

	case jsonb_typeof(_data)
		when 'object' then
			_pack := msgpack_object(_data);
		when 'array' then
			_pack := msgpack_array(_data);
		when 'number' then
			_numeric = (_data#>>'{}')::numeric;
			if _numeric % 1 != 0 then
				-- treat all floats as 64-bit floats
				_pack := msgpack_float(_numeric, false);
			else
				_pack := msgpack_integer(_numeric);
			end if;
		when 'string' then
			_pack := msgpack_text(_data);
		when 'boolean' then
			_pack := msgpack_boolean(_data::boolean);
		when 'null' then
			_pack := E'\\300'::bytea;
		else
			raise exception '% not implemented yet', jsonb_typeof(_data);
	end case;

	return _pack;

end;
$function$
