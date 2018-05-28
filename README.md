# timezone-json

Use the IANA time zone database (tzdb) to build a set of JSON files for all time zones. Each JSON file contains a time zone's offset at 1970 and a list of offset changes up to 2037. These can be used to compute local times from UTC times.

See the `elm` folder for examples of use with `elm/time`.

## Build

```bash
./build.sh
```

- clones the [IANA time zone database repository][tz]
- compiles the time zone information files for the latest release
- uses a script from [tz.js][tzjs] to read the compiled files
- writes a set of JSON files to `dist/<version>`

If the latest tzdb release is version `2018e`, then the file for "America/Los_Angeles" will be written to `dist/2018e/America/Los_Angeles.json`.

[tz]: https://github.com/eggert/tz
[tzjs]: https://github.com/dbaron/tz.js
