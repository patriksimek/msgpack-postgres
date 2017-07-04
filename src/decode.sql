create or replace function msgpack_decode(_data bytea) returns jsonb language plpgsql
as $function$
declare _length integer = octet_length(_data);
declare _cursor integer = 0;
declare _size integer;
declare _wrapper jsonb[];
declare _counter integer[];
declare _key text[];
declare _json jsonb;
declare _binary text;
declare _exponent integer;
declare _mantissa text;
declare _float double precision;
declare _index integer;
begin

	while _cursor < _length loop
		case get_byte(_data, _cursor)
			when 192 then -- null
				_json = 'null'::jsonb;
				_cursor = _cursor + 1;
			
			when 194 then -- false
				_json = to_jsonb(false);
				_cursor = _cursor + 1;
			
			when 195 then -- true
				_json = to_jsonb(true);
				_cursor = _cursor + 1;
			
			when 196 then -- bin 8
				_json = 'null'::jsonb;
				_cursor = _cursor + 2;
			
			when 197 then -- bin 16
				_json = 'null'::jsonb;
				_cursor = _cursor + 3;
			
			when 198 then -- bin 32
				_json = 'null'::jsonb;
				_cursor = _cursor + 5;
			
			when 199 then -- ext 8
				_json = 'null'::jsonb;
				_cursor = _cursor + 3;
			
			when 200 then -- ext 16
				_json = 'null'::jsonb;
				_cursor = _cursor + 4;
			
			when 201 then -- ext 32
				_json = 'null'::jsonb;
				_cursor = _cursor + 6;
			
			when 202 then -- float 32
				_binary = get_byte(_data, _cursor + 1)::bit(8)
					|| get_byte(_data, _cursor + 2)::bit(8)
					|| get_byte(_data, _cursor + 3)::bit(8)
					|| get_byte(_data, _cursor + 4)::bit(8);
				_exponent = substring(_binary, 2, 8)::bit(8)::integer;
				_mantissa = substring(_binary, 10, 23);

				if _exponent = 255 then
					-- Infinity, -Infinity, NaN
					_json = 'null'::jsonb;
				else
					_float = 1;
					_index = 1;
					_exponent = _exponent - 127;
				
					while _index < 24 loop
						if substring(_mantissa, _index, 1) = '1' then
							_float = _float + (2 ^ -(_index));
						end if;
						_index = _index + 1;
					end loop;

					_float = _float * (2 ^ _exponent);
					if substring(_binary, 1, 1) = '1' then
						_float = -_float;
					end if;
				end if;
				
				_json = to_jsonb(_float);
				_cursor = _cursor + 5;
			
			when 203 then -- float 64
				_binary = get_byte(_data, _cursor + 1)::bit(8)
					|| get_byte(_data, _cursor + 2)::bit(8)
					|| get_byte(_data, _cursor + 3)::bit(8)
					|| get_byte(_data, _cursor + 4)::bit(8)
					|| get_byte(_data, _cursor + 5)::bit(8)
					|| get_byte(_data, _cursor + 6)::bit(8)
					|| get_byte(_data, _cursor + 7)::bit(8)
					|| get_byte(_data, _cursor + 8)::bit(8);
				_exponent = substring(_binary, 2, 11)::bit(11)::integer;
				_mantissa = substring(_binary, 13, 52);

				if _exponent = 2047 then
					-- Infinity, -Infinity, NaN
					_json = 'null'::jsonb;
				else
					_float = 1;
					_index = 1;
					_exponent = _exponent - 1023;
				
					while _index < 53 loop
						if substring(_mantissa, _index, 1) = '1' then
							_float = _float + (2 ^ -(_index));
						end if;
						_index = _index + 1;
					end loop;

					_float = _float * (2 ^ _exponent);
					if substring(_binary, 1, 1) = '1' then
						_float = -_float;
					end if;
				end if;
				
				_json = to_jsonb(_float);
				_cursor = _cursor + 9;
			
			when 204 then -- uint 8
				_json = to_jsonb(get_byte(_data, _cursor + 1));
				_cursor = _cursor + 1;
			
			when 205 then -- uint 16
				_json = to_jsonb((get_byte(_data, _cursor + 1) << 8)
					+ get_byte(_data, _cursor + 2));
				_cursor = _cursor + 3;
			
			when 206 then -- uint 32
				_json = to_jsonb((get_byte(_data, _cursor + 1) << 24)
					+ (get_byte(_data, _cursor + 2) << 16)
					+ (get_byte(_data, _cursor + 3) << 8)
					+ get_byte(_data, _cursor + 4));
				_cursor = _cursor + 5;
			
			when 207 then -- uint 64
				_json = to_jsonb((get_byte(_data, _cursor + 1)::bigint << 56)
					+ (get_byte(_data, _cursor + 2)::bigint << 48)
					+ (get_byte(_data, _cursor + 3)::bigint << 40)
					+ (get_byte(_data, _cursor + 4)::bigint << 32)
					+ (get_byte(_data, _cursor + 5)::bigint << 24)
					+ (get_byte(_data, _cursor + 6)::bigint << 16)
					+ (get_byte(_data, _cursor + 7)::bigint << 8)
					+ get_byte(_data, _cursor + 8)::bigint);
				_cursor = _cursor + 9;
			
			when 208 then -- int 8
				_json = to_jsonb(-(2 ^ 8 - get_byte(_data, _cursor + 1)));
				_cursor = _cursor + 1;
			
			when 209 then -- int 16
				_json = to_jsonb(-(2 ^ 16 - (get_byte(_data, _cursor + 1) << 8)
					- get_byte(_data, _cursor + 2)));
				_cursor = _cursor + 3;
			
			when 210 then -- int 32
				_json = to_jsonb((get_byte(_data, _cursor + 1) << 24)
					+ (get_byte(_data, _cursor + 2) << 16)
					+ (get_byte(_data, _cursor + 3) << 8)
					+ get_byte(_data, _cursor + 4));
				_cursor = _cursor + 5;
			
			when 211 then -- int 64
				_json = to_jsonb((get_byte(_data, _cursor + 1)::bigint << 56)
					+ (get_byte(_data, _cursor + 2)::bigint << 48)
					+ (get_byte(_data, _cursor + 3)::bigint << 40)
					+ (get_byte(_data, _cursor + 4)::bigint << 32)
					+ (get_byte(_data, _cursor + 5)::bigint << 24)
					+ (get_byte(_data, _cursor + 6)::bigint << 16)
					+ (get_byte(_data, _cursor + 7)::bigint << 8)
					+ get_byte(_data, _cursor + 8)::bigint);
				_cursor = _cursor + 9;
			
			when 212 then -- fixext 1
				_json = 'null'::jsonb;
				_cursor = _cursor + 3;
			
			when 213 then -- fixext 2
				_json = 'null'::jsonb;
				_cursor = _cursor + 4;
			
			when 214 then -- fixext 4
				_json = 'null'::jsonb;
				_cursor = _cursor + 6;
			
			when 215 then -- fixext 8
				_json = 'null'::jsonb;
				_cursor = _cursor + 10;
			
			when 216 then -- fixext 16
				_json = 'null'::jsonb;
				_cursor = _cursor + 18;
			
			when 217 then -- str 8
				_size = get_byte(_data, _cursor + 1);
				_json = to_jsonb(convert_from(substring(_data, _cursor + 3, _size), 'utf8'));
				_cursor = _cursor + 2 + _size;
			
			when 218 then -- str 16
				_size = (get_byte(_data, _cursor + 1) << 8)
					+ get_byte(_data, _cursor + 2);
				_json = to_jsonb(convert_from(substring(_data, _cursor + 4, _size), 'utf8'));
				_cursor = _cursor + 3 + _size;
			
			when 219 then -- str 32
				_size = (get_byte(_data, _cursor + 1) << 24)
					+ (get_byte(_data, _cursor + 2) << 16)
					+ (get_byte(_data, _cursor + 3) << 8)
					+ get_byte(_data, _cursor + 4);
				_json = to_jsonb(convert_from(substring(_data, _cursor + 6, _size), 'utf8'));
				_cursor = _cursor + 5 + _size;
			
			when 220 then -- array 16
				_size = (get_byte(_data, _cursor + 1) << 8)
					+ get_byte(_data, _cursor + 2);
				_json = jsonb_build_array();
				_cursor = _cursor + 3;
				if _size > 0 then
					_wrapper = array_prepend(_json, _wrapper);
					_counter = array_prepend(_size, _counter);
					_key = array_prepend(null, _key);
					continue;
				end if;
			
			when 221 then -- array 32
				_size = (get_byte(_data, _cursor + 1) << 24)
					+ (get_byte(_data, _cursor + 2) << 16)
					+ (get_byte(_data, _cursor + 3) << 8)
					+ get_byte(_data, _cursor + 4);
				_json = jsonb_build_array();
				_cursor = _cursor + 5;
				if _size > 0 then
					_wrapper = array_prepend(_json, _wrapper);
					_counter = array_prepend(_size, _counter);
					_key = array_prepend(null, _key);
					continue;
				end if;
			
			when 222 then -- map 16
				_size = (get_byte(_data, _cursor + 1) << 8)
					+ get_byte(_data, _cursor + 2);
				_json = jsonb_build_object();
				_cursor = _cursor + 3;
				if _size > 0 then
					_wrapper = array_prepend(_json, _wrapper);
					_counter = array_prepend(_size, _counter);
					_key = array_prepend(null, _key);
					continue;
				end if;
			
			when 223 then -- map 32
				_size = (get_byte(_data, _cursor + 1) << 24)
					+ (get_byte(_data, _cursor + 2) << 16)
					+ (get_byte(_data, _cursor + 3) << 8)
					+ get_byte(_data, _cursor + 4);
				_json = jsonb_build_object();
				_cursor = _cursor + 5;
				if _size > 0 then
					_wrapper = array_prepend(_json, _wrapper);
					_counter = array_prepend(_size, _counter);
					_key = array_prepend(null, _key);
					continue;
				end if;
	
			else
				if get_byte(_data, _cursor) & 128 = 0 then -- positive fixint
					_json = to_jsonb(get_byte(_data, _cursor));
					_cursor = _cursor + 1;
				elsif get_byte(_data, _cursor) & 224 = 224 then -- negative fixint
					_json = to_jsonb(-(255 - get_byte(_data, _cursor) + 1));
					_cursor = _cursor + 1;
				elsif get_byte(_data, _cursor) & 224 = 160 then -- fixstr
					_size = get_byte(_data, _cursor) & 31;
					_json = to_jsonb(convert_from(substring(_data, _cursor + 2, _size), 'utf8'));
					_cursor = _cursor + 1 + _size;
				elsif get_byte(_data, _cursor) & 240 = 144 then -- fixarray
					_size = get_byte(_data, _cursor) & 15;
					_json = jsonb_build_array();
					_cursor = _cursor + 1;
					if _size > 0 then
						_wrapper = array_prepend(_json, _wrapper);
						_counter = array_prepend(_size, _counter);
						_key = array_prepend(null, _key);
						continue;
					end if;
				elsif get_byte(_data, _cursor) & 240 = 128 then -- fixmap
					_size = get_byte(_data, _cursor) & 15;
					_json = jsonb_build_object();
					_cursor = _cursor + 1;
					if _size > 0 then
						_wrapper = array_prepend(_json, _wrapper);
						_counter = array_prepend(_size, _counter);
						_key = array_prepend(null, _key);
						continue;
					end if;
				else
					raise exception 'Unknown type %.', get_byte(_data, _cursor);
				end if;
		end case;
		
		if _wrapper is null then
			return _json;
		elsif jsonb_typeof(_wrapper[1]) = 'array' then
			_wrapper[1] = _wrapper[1] || jsonb_build_array(_json);
		elsif jsonb_typeof(_wrapper[1]) = 'object' then
			if _key[1] is null then
				_key[1] = _json#>>'{}';
				continue;
			end if;
			_wrapper[1] = _wrapper[1] || jsonb_build_object(_key[1], _json);
			_key[1] = null;
		end if;

		_counter[1] = _counter[1] - 1;
		while _counter[1] <= 0 loop
			_json = _wrapper[1];
			
			_wrapper = _wrapper[2:array_upper(_wrapper, 1)];
			_counter = _counter[2:array_upper(_counter, 1)];
			_key = _key[2:array_upper(_key, 1)];

			if array_length(_wrapper, 1) is null then
				return _json;
			elsif jsonb_typeof(_wrapper[1]) = 'array' then
				_wrapper[1] = _wrapper[1] || jsonb_build_array(_json);
			elsif jsonb_typeof(_wrapper[1]) = 'object' then
				_wrapper[1] = _wrapper[1] || jsonb_build_object(_key[1], _json);
				_key[1] = null;
			end if;
			
			_counter[1] = _counter[1] - 1;
		end loop;
	end loop;

end;
$function$;
