module Examples exposing (main)

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
    Result String ( String, Time.Zone )


type Msg
    = ReceiveTimeZone (Result String ( String, Time.Zone ))


init : ( Model, Cmd Msg )
init =
    ( Err "Loading"
    , Time.getZoneName
        |> Task.andThen
            (\nameOrOffset ->
                case nameOrOffset of
                    Time.Name zoneName ->
                        fetchTimeZone zoneName
                            |> Task.map (Tuple.pair zoneName)
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
        "Examples"
        (case result of
            Err message ->
                [ Html.pre [ Html.Attributes.style "color" "red" ] [ Html.text message ] ]

            Ok ( zoneName, zone ) ->
                [ Html.pre
                    []
                    [ [ "Examples of Posix times displayed in UTC and your local time:"
                      , ""
                      , "UTC                      | " ++ zoneName
                      , "------------------------ | ------------------------"
                      ]
                        ++ ([ 867564229068
                            , 1131357044194
                            , 1467083800795
                            , 1501214531979
                            , 1512980764516
                            , 1561825998564
                            , 1689782246881
                            ]
                                |> List.map Time.millisToPosix
                                |> List.map
                                    (\posix ->
                                        (posix |> formatPosix Time.utc) ++ " | " ++ (posix |> formatPosix zone)
                                    )
                           )
                        |> String.join "\n"
                        |> Html.text
                    ]
                ]
        )


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
