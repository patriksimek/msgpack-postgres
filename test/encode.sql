do $$ begin
assert (select public.msgpack_encode('null'::jsonb)) = decode('c0', 'hex'), 'Null #1';

assert (select public.msgpack_encode('"text"'::jsonb)) = decode('a474657874', 'hex'), 'String #1';
assert (select public.msgpack_encode('"Příliš žluťoučký kůň úpěl ďábelské ódy."'::jsonb)) = decode('d93650c599c3ad6c69c5a120c5be6c75c5a56f75c48d6bc3bd206bc5afc58820c3ba70c49b6c20c48fc3a162656c736bc3a920c3b364792e', 'hex'), 'String #2';

assert (select public.msgpack_encode('true'::jsonb)) = decode('c3', 'hex'), 'Boolean #1';
assert (select public.msgpack_encode('false'::jsonb)) = decode('c2', 'hex'), 'Boolean #2';

assert (select public.msgpack_encode('13'::jsonb)) = decode('0d', 'hex'), 'Integer #1';
assert (select public.msgpack_encode('-13'::jsonb)) = decode('f3', 'hex'), 'Integer #2';
assert (select public.msgpack_encode('133'::jsonb)) = decode('cc85', 'hex'), 'Integer #3';
assert (select public.msgpack_encode('-133'::jsonb)) = decode('d1ff7b', 'hex'), 'Integer #4';
assert (select public.msgpack_encode('1337'::jsonb)) = decode('cd0539', 'hex'), 'Integer #5';
assert (select public.msgpack_encode('-1337'::jsonb)) = decode('d1fac7', 'hex'), 'Integer #6';
assert (select public.msgpack_encode('133700'::jsonb)) = decode('ce00020a44', 'hex'), 'Integer #7';
assert (select public.msgpack_encode('-133700'::jsonb)) = decode('d2fffdf5bc', 'hex'), 'Integer #8';
assert (select public.msgpack_encode('2147483647'::jsonb)) = decode('ce7fffffff', 'hex'), 'Integer #9';
assert (select public.msgpack_encode('-2147483647'::jsonb)) = decode('d280000001', 'hex'), 'Integer #10';
assert (select public.msgpack_encode('9223372036854775807'::jsonb)) = decode('cf7fffffffffffffff', 'hex'), 'Integer #11';
assert (select public.msgpack_encode('-9223372036854775807'::jsonb)) = decode('d38000000000000001', 'hex'), 'Integer #12';

assert (select public.msgpack_encode('1.337'::jsonb) = decode('cb3ff5645a1cac0831', 'hex')), 'Double #1';
assert (select public.msgpack_encode('0.005'::jsonb) = decode('cb3f747ae147ae147b', 'hex')), 'Double #2';
assert (select public.msgpack_encode('-1.337'::jsonb) = decode('cbbff5645a1cac0831', 'hex')), 'Double #3';

assert (select public.msgpack_encode('[]'::jsonb)) = decode('90', 'hex'), 'Array #1';
assert (select public.msgpack_encode('[1]'::jsonb)) = decode('9101', 'hex'), 'Array #2';
assert (select public.msgpack_encode('[1,"x"]'::jsonb)) = decode('9201a178', 'hex'), 'Array #3';
assert (select public.msgpack_encode('[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]'::jsonb)) = decode('dc00100102030405060708090a0b0c0d0e0f10', 'hex'), 'Array #4';

assert (select public.msgpack_encode('{}'::jsonb)) = decode('80', 'hex'), 'Object #1';
assert (select public.msgpack_encode('{"a":1,"b":2}'::jsonb)) = decode('82a16101a16202', 'hex'), 'Object #2';

assert (select public.msgpack_encode('{"int":-1337,"null":null,"true":true,"uint":1337,"array":[1,2],"false":false,"string":"string","emptyarray":[],"emptyobject":{}}'::jsonb)) = decode('89a3696e74d1fac7a46e756c6cc0a474727565c3a475696e74cd0539a56172726179920102a566616c7365c2a6737472696e67a6737472696e67aa656d707479617272617990ab656d7074796f626a65637480', 'hex'), 'Complex #1';
end $$