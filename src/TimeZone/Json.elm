module TimeZone.Json exposing (Error(..), getZone, getZoneByName)

import Http
import Json.Decode as Decode exposing (Decoder)
import Task exposing (Task)
import Time


type Error
    = NoZoneName
    | HttpError String Http.Error


getZone : String -> Task Error ( String, Time.Zone )
getZone pathToJson =
    Time.getZoneName
        |> Task.andThen
            (\nameOrOffset ->
                case nameOrOffset of
                    Time.Name zoneName ->
                        getZoneByName pathToJson zoneName
                            |> Task.map (Tuple.pair zoneName)
                            |> Task.mapError (HttpError zoneName)

                    Time.Offset _ ->
                        Task.fail NoZoneName
            )


getZoneByName : String -> String -> Task Http.Error Time.Zone
getZoneByName pathToJson zoneName =
    Http.get
        (pathToJson ++ "/" ++ zoneName ++ ".json")
        decodeZone
        |> Http.toTask


decodeZone : Decoder Time.Zone
decodeZone =
    Decode.map2 Time.customZone
        (Decode.index 1 Decode.int)
        (Decode.index 0 (Decode.list decodeOffsetChange))


decodeOffsetChange : Decoder { start : Int, offset : Int }
decodeOffsetChange =
    Decode.map2 (\a b -> { start = a, offset = b })
        (Decode.index 0 Decode.int)
        (Decode.index 1 Decode.int)
