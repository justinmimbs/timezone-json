module FetchZone exposing (main)

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
    { times : List Posix
    , timeZone : Remote Time.Zone
    }


type Msg
    = ReceiveTimeZone (Result Http.Error Time.Zone)


type Remote a
    = Loading
    | Success a
    | Failure Http.Error


init : ( Model, Cmd Msg )
init =
    ( { times =
            List.map Time.millisToPosix
                [ 867564229068
                , 1131357044194
                , 1467083800795
                , 1501214531979
                , 1512980764516
                , 1561825998564
                , 1689782246881
                ]
      , timeZone = Loading
      }
    , Time.getZoneName
        |> Task.andThen
            (\nameOrOffset ->
                case nameOrOffset of
                    Time.Name zoneName ->
                        fetchTimeZone zoneName

                    Time.Offset offset ->
                        Task.succeed (Time.customZone offset [])
            )
        |> Task.attempt ReceiveTimeZone
    )



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update (ReceiveTimeZone result) model =
    ( case result of
        Ok timeZone ->
            { model | timeZone = Success timeZone }

        Err error ->
            { model | timeZone = Failure error }
    , Cmd.none
    )



-- remote time zone


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


view : Model -> Browser.Page Msg
view model =
    Browser.Page
        "FetchZone"
        [ case model.timeZone of
            Loading ->
                Html.text "Loading"

            Failure error ->
                Html.text (Debug.toString error)

            Success localZone ->
                Html.pre
                    []
                    [ Html.text "UTC                      | Local\n"
                    , Html.text "------------------------ | ------------------------\n"
                    , model.times
                        |> List.map
                            (\time ->
                                (time |> formatPosix Time.utc)
                                    ++ " | "
                                    ++ (time |> formatPosix localZone)
                            )
                        |> String.join "\n"
                        |> Html.text
                    ]
        ]


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
