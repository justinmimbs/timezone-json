module Main exposing (main)

import Browser
import Dict exposing (Dict)
import Html exposing (Html)
import Http
import Json.Decode as Decode exposing (Decoder, Value)
import Task exposing (Task)
import Time exposing (Posix)


main : Program TimeZone Model Msg
main =
    Browser.embed
        { init = init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }


type alias Model =
    { js : TimeZone
    , tz : Result String TimeZone
    }


type alias TimeZone =
    { name : String
    , changes : List { start : Int, offset : Int }
    , initial : Int
    }


type Msg
    = ReceiveTimeZone (Result String TimeZone)


utc : TimeZone
utc =
    TimeZone "UTC" [] 0


init : TimeZone -> ( Model, Cmd Msg )
init zone =
    ( { js = zone
      , tz = Err "Loading"
      }
    , Time.getZoneName
        |> Task.andThen
            (\nameOrOffset ->
                case nameOrOffset of
                    Time.Name zoneName ->
                        fetchTimeZone zoneName
                            |> Task.mapError (\_ -> "Couldn't load time zone: " ++ zoneName)

                    Time.Offset offset ->
                        Task.fail "Couldn't get time zone name"
            )
        |> Task.attempt ReceiveTimeZone
    )



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update (ReceiveTimeZone result) model =
    ( { model | tz = result } |> Debug.log "model"
    , Cmd.none
    )



-- time zone


fetchTimeZone : String -> Task Http.Error TimeZone
fetchTimeZone zoneName =
    Http.get
        ("/dist/2018e/" ++ zoneName ++ ".json")
        (Decode.map2 (TimeZone zoneName)
            (Decode.index 0 (Decode.list decodeOffsetChange))
            (Decode.index 1 Decode.int)
        )
        |> Http.toTask


decodeOffsetChange : Decoder { start : Int, offset : Int }
decodeOffsetChange =
    Decode.map2 (\a b -> { start = a, offset = b })
        (Decode.index 0 Decode.int)
        (Decode.index 1 Decode.int)



-- view


view : Model -> Html Msg
view { js, tz } =
    case tz of
        Err message ->
            Html.text message

        Ok zone ->
            let
                colWidth =
                    31
            in
            Html.pre
                []
                [ (js.name |> String.left colWidth |> String.padRight colWidth ' ')
                    ++ " | "
                    ++ zone.name
                    ++ "\n"
                    |> Html.text
                , String.repeat colWidth "-"
                    ++ " | "
                    ++ String.repeat colWidth "-"
                    ++ "\n"
                    |> Html.text
                , compareTimeZones js zone
                    |> List.map (formatDiff colWidth)
                    |> String.join "\n"
                    |> Html.text
                ]


type Diff
    = A String
    | B String
    | AB String String


formatDiff : Int -> Diff -> String
formatDiff colWidth diff =
    case diff of
        A a ->
            a ++ " | "

        B b ->
            String.repeat colWidth " " ++ " | " ++ b

        AB a b ->
            a ++ " | " ++ b


compareTimeZones : TimeZone -> TimeZone -> List Diff
compareTimeZones a b =
    Dict.merge
        (\_ desc diffs -> A desc :: diffs)
        (\_ descA descB diffs ->
            if descA == descB then
                diffs

            else
                AB descA descB :: diffs
        )
        (\_ desc diffs -> B desc :: diffs)
        (indexChanges a.initial (List.reverse a.changes))
        (indexChanges b.initial (List.reverse b.changes))
        []


indexChanges : Int -> List { start : Int, offset : Int } -> Dict ( Int, Int ) String
indexChanges initial changes =
    List.map2
        (\prevOffset { start, offset } ->
            let
                adjustedStart =
                    start * 60000 + prevOffset * 60000 |> Time.millisToPosix

                year =
                    adjustedStart |> Time.toYear Time.utc

                desc =
                    (adjustedStart |> formatPosix Time.utc)
                        ++ " -> "
                        ++ (offset |> offsetToString)
            in
            ( year, desc )
        )
        (initial :: (changes |> List.map .offset))
        changes
        |> List.foldl
            (\( year, desc ) ( prevKey, dict ) ->
                let
                    key =
                        case prevKey of
                            Nothing ->
                                ( year, 1 )

                            Just ( prevYear, n ) ->
                                if year == prevYear then
                                    ( year, n + 1 )

                                else
                                    ( year, 1 )
                in
                ( Just key, dict |> Dict.insert key desc )
            )
            ( Nothing, Dict.empty )
        |> Tuple.second


offsetToString : Int -> String
offsetToString offset =
    (if offset < 0 then
        "-"

     else
        "+"
    )
        ++ (abs offset // 60 |> String.fromInt |> String.padLeft 2 '0')
        ++ ":"
        ++ (abs offset |> modBy 60 |> String.fromInt |> String.padLeft 2 '0')


formatPosix : Time.Zone -> Posix -> String
formatPosix zone posix =
    String.join " "
        [ Time.toWeekday zone posix |> Debug.toString
        , Time.toMonth zone posix |> Debug.toString
        , Time.toDay zone posix |> String.fromInt |> String.padLeft 2 '0'
        , Time.toYear zone posix |> String.fromInt
        , String.join ":"
            [ Time.toHour zone posix |> String.fromInt |> String.padLeft 2 '0'
            , Time.toMinute zone posix |> String.fromInt |> String.padLeft 2 '0'
            ]
        ]
