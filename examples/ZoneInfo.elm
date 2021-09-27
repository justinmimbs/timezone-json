module ZoneInfo exposing (main)

import Browser
import Format exposing (formatPosix)
import Html exposing (Html)
import Html.Attributes
import Http
import Json.Decode as Decode exposing (Decoder)
import Task exposing (Task)
import Time exposing (Posix)
import TimeZone.Json exposing (ZoneInfo)


main : Program () Model Msg
main =
    Browser.document
        { init = always init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }


type alias Model =
    Result String ZoneInfo


type Msg
    = ReceiveZoneInfo (Result String ZoneInfo)


init : ( Model, Cmd Msg )
init =
    ( Err "Loading"
    , Time.getZoneName
        |> Task.andThen
            (\nameOrOffset ->
                case nameOrOffset of
                    Time.Name zoneName ->
                        TimeZone.Json.getZoneInfoByName "/dist/2021b/" zoneName
                            |> Task.mapError Debug.toString

                    Time.Offset offset ->
                        Task.fail "Couldn't get your local time zone name"
            )
        |> Task.attempt ReceiveZoneInfo
    )



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update (ReceiveZoneInfo result) _ =
    ( result
    , Cmd.none
    )



-- view


view : Model -> Browser.Document Msg
view result =
    Browser.Document
        "ZoneInfo"
        (case result of
            Err message ->
                [ colorText "red" message ]

            Ok tz ->
                [ colorText "black"
                    ([ "This is the information loaded for your local zone. Offset changes are"
                     , "displayed as [local time]  ->  [UTC offset]."
                     ]
                        |> String.join "\n"
                    )
                , colorText "gray" "Time zone name:"
                , colorText "black" (indent tz.name)
                , colorText "gray" "Initial offset:"
                , colorText "black" (indent (tz.initial |> offsetToString))
                , colorText "gray" "Offset changes:"
                , colorText "black" (formatChanges tz.initial (List.reverse tz.changes) |> List.map indent |> String.join "\n")
                ]
        )


indent : String -> String
indent s =
    "    " ++ s


colorText : String -> String -> Html a
colorText color text =
    Html.pre [ Html.Attributes.style "color" color ] [ Html.text text ]


formatChanges : Int -> List { start : Int, offset : Int } -> List String
formatChanges initial changes =
    List.map2
        (\previous { start, offset } ->
            (start * 60000 + previous * 60000 |> Time.millisToPosix |> formatPosix Time.utc)
                ++ "  ->  "
                ++ (offset |> offsetToString)
        )
        (initial :: (changes |> List.map .offset))
        changes


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
