# msgpack-postgres [![Travis CI][travis-image]][travis-url]

MessagePack implementation for PostgreSQL written in PL/pgSQL.

## Installation

Execute `src/encode.sql` or/and `src/decode.sql` on your database server.

## Quick Example

```sql
select msgpack_encode('{"hello": "world"}'::jsonb);
-- returns 0x81a568656c6c6fa5776f726c64

select msgpack_decode(decode('81a568656c6c6fa5776f726c64', 'hex'));
-- returns '{"hello": "world"}'
```

## Documentation

`msgpack_encode(jsonb)`

Encodes `jsonb` object into `bytea` string.

`msgpack_decode(bytea)`

Decodes `jsonb` object from `bytea` string.

## TODO

- Float/double encoding
- Ignore unsupported types when decoding

## Sponsors

Development is sponsored by [Integromat](https://www.integromat.com/en/integrations/postgres).

## License

Copyright (c) 2017 Patrik Simek

The MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

[travis-image]: https://img.shields.io/travis/patriksimek/msgpack-postgres/master.svg?style=flat-square&label=unit
[travis-url]: https://travis-ci.org/patriksimek/msgpack-postgres
