module Tests exposing (main)

import Browser
import Dict exposing (Dict)
import Format exposing (formatPosix)
import Html exposing (Html)
import Html.Attributes
import Http
import Json.Decode as Decode exposing (Decoder, Value)
import Local
import Task exposing (Task)
import Time exposing (Posix)
import TimeZone.Json


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
    = ReceiveTimeZone (Result TimeZone.Json.Error ( String, Time.Zone ))


init : ( Model, Cmd Msg )
init =
    ( Err "Loading"
    , TimeZone.Json.getZone "/dist/2018e"
        |> Task.attempt ReceiveTimeZone
    )



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update (ReceiveTimeZone result) _ =
    ( case result of
        Ok ( zoneName, zone ) ->
            Ok (TimeZone zoneName zone)

        Err error ->
            Err "Cannot run tests; failed to get local time zone"
    , Cmd.none
    )



-- tests


testExamples : Time.Zone -> List ( Int, String ) -> List ( Int, String, String )
testExamples zone samples =
    samples
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



-- view


view : Model -> Browser.Document Msg
view model =
    Browser.Document
        "Tests"
        (case model of
            Err message ->
                [ colorText "red" message ]

            Ok { name, zone } ->
                let
                    failed =
                        testExamples zone Local.examples
                            |> List.map
                                (\( time, expected, result ) ->
                                    [ String.fromInt time
                                    , "    expected: " ++ expected
                                    , "    result:   " ++ result
                                    ]
                                        |> String.join "\n"
                                )

                    summary =
                        [ "Tested: " ++ String.fromInt (List.length Local.examples)
                        , "Failed: " ++ String.fromInt (List.length failed)
                        ]
                in
                [ colorText "black"
                    ([ "Test that converting a POSIX time to local time in Elm (using 'elm/time' and"
                     , "the loaded local zone, '" ++ name ++ "') matches the result produced by"
                     , "your system (not your browser). If your system uses time zone information that"
                     , "differs from the current tzdb, then the output may not match."
                     ]
                        |> String.join "\n"
                    )
                , colorText "black" (summary |> String.join "\n")
                , colorText "red" (failed |> String.join "\n")
                ]
        )


colorText : String -> String -> Html a
colorText color text =
    Html.pre [ Html.Attributes.style "color" color ] [ Html.text text ]
