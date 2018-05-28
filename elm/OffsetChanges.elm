module OffsetChanges exposing (main)

import Browser
import Html exposing (Html)
import Http
import Json.Decode as Decode exposing (Decoder)
import Task exposing (Task)
import Time exposing (Posix)


main : Program () Model Msg
main =
    Browser.fullscreen
        { init = always init
        , view = view
        , update = update
        , onNavigation = Nothing
        , subscriptions = always Sub.none
        }


type alias Model =
    TimeZone


type alias TimeZone =
    { name : String
    , changes : List { start : Int, offset : Int }
    , initial : Int
    }


type Msg
    = ReceiveTimeZone TimeZone


utc : TimeZone
utc =
    TimeZone "UTC" [] 0


init : ( Model, Cmd Msg )
init =
    ( utc
    , Time.getZoneName
        |> Task.andThen
            (\nameOrOffset ->
                case nameOrOffset of
                    Time.Name zoneName ->
                        fetchTimeZone zoneName

                    Time.Offset offset ->
                        Task.succeed utc
            )
        |> Task.onError (\_ -> Task.succeed utc)
        |> Task.perform ReceiveTimeZone
    )



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update (ReceiveTimeZone timeZone) _ =
    ( timeZone
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


view : Model -> Browser.Page Msg
view tz =
    Browser.Page
        "FetchZone"
        [ Html.pre
            []
            [ Html.text (tz.name ++ "\n")
            , Html.text ((tz.initial |> offsetToString) ++ "\n")
            , Html.text (formatChanges tz.initial (List.reverse tz.changes) |> String.join "\n")
            ]
        ]


formatChanges : Int -> List { start : Int, offset : Int } -> List String
formatChanges initial changes =
    List.map2
        (\previous { start, offset } ->
            (start * 60000 + previous * 60000 |> Time.millisToPosix |> formatPosix Time.utc)
                ++ " => "
                ++ (offset |> offsetToString)
        )
        (initial :: (changes |> List.map .offset))
        changes


offsetToString : Int -> String
offsetToString offset =
    let
        sign =
            if offset < 0 then
                "-"

            else
                "+"
    in
    sign
        ++ (abs offset // 60 |> String.fromInt |> String.padLeft 2 '0')
        ++ ":"
        ++ (offset |> modBy 60 |> String.fromInt |> String.padLeft 2 '0')


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
            , Time.toSecond zone posix |> String.fromInt |> String.padLeft 2 '0'
            ]
        ]
