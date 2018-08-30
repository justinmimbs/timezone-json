# timezone-json

Use the [IANA Time Zone Database][tzdb] to build a set of JSON files for all time zones. Each JSON file contains a time zone's offset at 1970 and a list of offset changes through 2037.


## Build

```bash
./build.sh
```

- clones the IANA Time Zone Database [repository][tz]
- compiles zone information files for the latest release
- uses a script from [tz.js][tzjs] to read the compiled files
- writes a set of JSON files to `dist/<version>`

For example, if the latest release is version `2018e`, then the file for _America/Los_Angeles_ will be written to `dist/2018e/America/Los_Angeles.json`.


## Elm examples

The [`elm/time`][elmtime] library provides a `Posix` type for representing an instant in time. Extracting human-readable parts from a `Posix` time requires a `Time.Zone`. These JSON files can be used by Elm applications that need `Time.Zone` values at runtime.

For an example of fetching and decoding `Time.Zone` values, see the `getZone` function in [this file][tzjson]; it takes a path to your JSON files and returns a task for getting the local zone name and zone as a `( String, Time.Zone )`.

```elm
import Time
import TimeZone.Json exposing (Error)

getLocalZone : Task Error ( String, Time.Zone )
getLocalZone =
    TimeZone.Json.getZone "/dist/2018e"
```

See [`examples/GetZone.elm`][getzone] for a full example.


[tzdb]: https://www.iana.org/time-zones
[tz]: https://github.com/eggert/tz
[tzjs]: https://github.com/dbaron/tz.js
[elmtime]: https://package.elm-lang.org/packages/elm/time/latest/
[tzjson]: https://github.com/justinmimbs/timezone-json/blob/master/src/TimeZone/Json.elm
[getzone]: https://github.com/justinmimbs/timezone-json/blob/master/examples/GetZone.elm
