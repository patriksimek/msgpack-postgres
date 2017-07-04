do $$ begin
assert (select public.msgpack_decode(decode('c0', 'hex'))::text) = 'null', 'Null #1';

assert (select public.msgpack_decode(decode('a474657874', 'hex'))::text) = '"text"', 'String #1';
assert (select public.msgpack_decode(decode('d93650c599c3ad6c69c5a120c5be6c75c5a56f75c48d6bc3bd206bc5afc58820c3ba70c49b6c20c48fc3a162656c736bc3a920c3b364792e', 'hex'))::text) = '"Příliš žluťoučký kůň úpěl ďábelské ódy."', 'String #2';

assert (select public.msgpack_decode(decode('c3', 'hex'))::text) = 'true', 'Boolean #1';
assert (select public.msgpack_decode(decode('c2', 'hex'))::text) = 'false', 'Boolean #2';

assert (select public.msgpack_decode(decode('0d', 'hex'))::text) = '13', 'Integer #1';
assert (select public.msgpack_decode(decode('f3', 'hex'))::text) = '-13', 'Integer #2';
assert (select public.msgpack_decode(decode('cc85', 'hex'))::text) = '133', 'Integer #3';
assert (select public.msgpack_decode(decode('d1ff7b', 'hex'))::text) = '-133', 'Integer #4';
assert (select public.msgpack_decode(decode('cd0539', 'hex'))::text) = '1337', 'Integer #5';
assert (select public.msgpack_decode(decode('d1fac7', 'hex'))::text) = '-1337', 'Integer #6';
assert (select public.msgpack_decode(decode('ce00020a44', 'hex'))::text) = '133700', 'Integer #7';
assert (select public.msgpack_decode(decode('d2fffdf5bc', 'hex'))::text) = '-133700', 'Integer #8';
assert (select public.msgpack_decode(decode('ce7fffffff', 'hex'))::text) = '2147483647', 'Integer #9';
assert (select public.msgpack_decode(decode('d280000001', 'hex'))::text) = '-2147483647', 'Integer #10';
assert (select public.msgpack_decode(decode('cf7fffffffffffffff', 'hex'))::text) = '9223372036854775807', 'Integer #11';
assert (select public.msgpack_decode(decode('d38000000000000001', 'hex'))::text) = '-9223372036854775807', 'Integer #12';
	
assert (select public.msgpack_decode(decode('ca3fab22d1', 'hex'))::text) = '1.33700001239777', 'Float #1';
assert (select public.msgpack_decode(decode('ca3ba3d70a', 'hex'))::text) = '0.00499999988824129', 'Float #2';

assert (select public.msgpack_decode(decode('cb3ff5645a1cac0831', 'hex'))::text) = '1.337', 'Double #1';
assert (select public.msgpack_decode(decode('cb3f747ae147ae147b', 'hex'))::text) = '0.005', 'Double #2';
assert (select public.msgpack_decode(decode('cbbff5645a1cac0831', 'hex'))::text) = '-1.337', 'Double #3';

assert (select public.msgpack_decode(decode('90', 'hex'))::text) = '[]', 'Array #1';
assert (select public.msgpack_decode(decode('9101', 'hex'))::text) = '[1]', 'Array #2';
assert (select public.msgpack_decode(decode('9201a178', 'hex'))::text) = '[1, "x"]', 'Array #3';
assert (select public.msgpack_decode(decode('dc00100102030405060708090a0b0c0d0e0f10', 'hex'))::text) = '[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]', 'Array #4';

assert (select public.msgpack_decode(decode('80', 'hex'))::text) = '{}', 'Object #1';
assert (select public.msgpack_decode(decode('82a16101a16202', 'hex'))::text) = '{"a": 1, "b": 2}', 'Object #2';

assert (select public.msgpack_decode(decode('89a3696e74d1fac7a46e756c6cc0a474727565c3a475696e74cd0539a56172726179920102a566616c7365c2a6737472696e67a6737472696e67aa656d707479617272617990ab656d7074796f626a65637480', 'hex'))::text) = '{"int": -1337, "null": null, "true": true, "uint": 1337, "array": [1, 2], "false": false, "string": "string", "emptyarray": [], "emptyobject": {}}', 'Complex #1';
end $$