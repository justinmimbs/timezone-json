module Tests exposing (main)

import Browser
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes
import Http
import Json.Decode as Decode exposing (Decoder, Value)
import Task exposing (Task)
import Tests.Local as Local
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
    , zone : Time.Zone
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
                            |> Task.map (TimeZone zoneName)
                            |> Task.mapError (\_ -> "Couldn't load time zone: " ++ zoneName)

                    Time.Offset offset ->
                        Task.fail "Couldn't get time zone name"
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


fetchTimeZone : String -> Task Http.Error Time.Zone
fetchTimeZone zoneName =
    Http.get
        ("/dist/2018e/" ++ zoneName ++ ".json")
        decodeTimeZone
        |> Http.toTask


decodeTimeZone : Decoder Time.Zone
decodeTimeZone =
    Decode.map2 Time.customZone
        (Decode.index 1 Decode.int)
        (Decode.index 0 (Decode.list decodeOffsetChange))


decodeOffsetChange : Decoder { start : Int, offset : Int }
decodeOffsetChange =
    Decode.map2 (\a b -> { start = a, offset = b })
        (Decode.index 0 Decode.int)
        (Decode.index 1 Decode.int)



-- view


view : Model -> Browser.Document Msg
view result =
    Browser.Document
        "Tests"
        (case result of
            Err message ->
                [ colorText "red" message ]

            Ok { name, zone } ->
                let
                    failing =
                        testExamples zone Local.examples
                            |> List.map Debug.toString

                    summary =
                        "Tested: "
                            ++ String.fromInt (List.length Local.examples)
                            ++ "\nFailed: "
                            ++ String.fromInt (List.length failing)
                in
                [ colorText "black"
                    ([ "Test that converting a POSIX time to local time in Elm (using 'elm/time' and"
                     , "the loaded local zone, '" ++ name ++ "') matches the result produced by"
                     , "your system (not your browser). If your system uses time zone information that"
                     , "differs from the current tzdb, then the output may not match."
                     ]
                        |> String.join "\n"
                    )
                , colorText "black" summary
                , colorText "red" (failing |> String.join "\n")
                ]
        )


colorText : String -> String -> Html a
colorText color text =
    Html.pre [ Html.Attributes.style "color" color ] [ Html.text text ]


testExamples : Time.Zone -> List ( Int, String ) -> List ( Int, String, String )
testExamples zone examples =
    examples
        |> List.filterMap
            (\( t, expected ) ->
                let
                    result =
                        Time.millisToPosix t |> formatPosix zone
                in
                if result == expected then
                    Nothing

                else
                    Just ( t, expected, result )
            )
        |> List.sortBy (\( a, _, _ ) -> a)


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
