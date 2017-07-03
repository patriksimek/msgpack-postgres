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
				raise exception 'Float not implemented yet.';
			end if;

			if _numeric > 0 then
				-- Integer
				if _numeric < 2 ^ 7 then
					_pack = set_byte(E' '::bytea, 0, _numeric::integer);
				elsif _numeric < 2 ^ 8 then
					_pack = E'\\314'::bytea
						|| set_byte(E' '::bytea, 0, _numeric::integer);
				elsif _numeric < 2 ^ 16 then
					_pack = E'\\315'::bytea
						|| set_byte(E' '::bytea, 0, (_numeric::integer >> 8) & 255)
						|| set_byte(E' '::bytea, 0, _numeric::integer & 255);
				elsif _numeric < 2 ^ 32 then
					_pack = E'\\316'::bytea
						|| set_byte(E' '::bytea, 0, (_numeric::integer >> 24) & 255)
						|| set_byte(E' '::bytea, 0, (_numeric::integer >> 16) & 255)
						|| set_byte(E' '::bytea, 0, (_numeric::integer >> 8) & 255)
						|| set_byte(E' '::bytea, 0, _numeric::integer & 255);
				elsif _numeric < 2 ^ 64 then
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
