module TimeZone.Json exposing
    ( Error(..), getZone, getZoneByName
    , ZoneInfo, getZoneInfoByName
    )

{-|

@docs Error, getZone, getZoneByName
@docs ZoneInfo, getZoneInfoByName

-}

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
    Http.task
        { method = "GET"
        , headers = []
        , url = pathToJson ++ "/" ++ zoneName ++ ".json"
        , body = Http.emptyBody
        , resolver = resolveJson decodeZone
        , timeout = Nothing
        }


type alias ZoneInfo =
    { name : String
    , changes : List { start : Int, offset : Int }
    , initial : Int
    }


getZoneInfoByName : String -> String -> Task Http.Error ZoneInfo
getZoneInfoByName pathToJson zoneName =
    Http.task
        { method = "GET"
        , headers = []
        , url = pathToJson ++ "/" ++ zoneName ++ ".json"
        , body = Http.emptyBody
        , resolver =
            resolveJson
                (Decode.map2 (ZoneInfo zoneName)
                    (Decode.index 0 (Decode.list decodeOffsetChange))
                    (Decode.index 1 Decode.int)
                )
        , timeout = Nothing
        }


resolveJson : Decoder a -> Http.Resolver Http.Error a
resolveJson decoder =
    Http.stringResolver
        (\response ->
            case response of
                Http.BadUrl_ url ->
                    Err <| Http.BadUrl url

                Http.Timeout_ ->
                    Err <| Http.Timeout

                Http.NetworkError_ ->
                    Err <| Http.NetworkError

                Http.BadStatus_ { statusCode } _ ->
                    Err <| Http.BadStatus statusCode

                Http.GoodStatus_ _ json ->
                    json
                        |> Decode.decodeString decoder
                        |> Result.mapError (Http.BadBody << Decode.errorToString)
        )


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
