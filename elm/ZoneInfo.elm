module ZoneInfo exposing (main)

import Browser
import Html exposing (Html)
import Html.Attributes
import Http
import Json.Decode as Decode exposing (Decoder)
import Task exposing (Task)
import Time exposing (Posix)


main : Program () Model Msg
main =
    Browser.document
        { init = always init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }


type alias Model =
    Result String TimeZone


type alias TimeZone =
    { name : String
    , changes : List { start : Int, offset : Int }
    , initial : Int
    }


type Msg
    = ReceiveTimeZone (Result String TimeZone)


init : ( Model, Cmd Msg )
init =
    ( Err "Loading"
    , Time.getZoneName
        |> Task.andThen
            (\nameOrOffset ->
                case nameOrOffset of
                    Time.Name zoneName ->
                        fetchTimeZone zoneName
                            |> Task.mapError Debug.toString

                    Time.Offset offset ->
                        Task.fail "Couldn't get your local time zone name"
            )
        |> Task.attempt ReceiveTimeZone
    )



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update (ReceiveTimeZone result) _ =
    ( result
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
