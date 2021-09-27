module GetZone exposing (main)

import Browser
import Format exposing (formatPosix)
import Html exposing (Html)
import Html.Attributes
import Task exposing (Task)
import Time exposing (Month(..), Posix, Weekday(..))
import TimeZone.Json


main : Program () Model Msg
main =
    Browser.document
        { init = always init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }


type Model
    = Loading
    | Failure TimeZone.Json.Error
    | Success ( String, Time.Zone )


type Msg
    = ReceiveTimeZone (Result TimeZone.Json.Error ( String, Time.Zone ))


init : ( Model, Cmd Msg )
init =
    ( Loading
    , TimeZone.Json.getZone "/dist/2021b"
        |> Task.attempt ReceiveTimeZone
    )



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update (ReceiveTimeZone result) _ =
    ( case result of
        Ok data ->
            Success data

        Err error ->
            Failure error
    , Cmd.none
    )



-- view


view : Model -> Browser.Document Msg
view model =
    Browser.Document
        "Get Zone"
        (case model of
            Loading ->
                [ Html.pre [] [ Html.text "Loading..." ] ]

            Failure error ->
                [ Html.pre [ Html.Attributes.style "color" "red" ] [ Html.text (error |> errorToString) ] ]

            Success ( zoneName, zone ) ->
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


errorToString : TimeZone.Json.Error -> String
errorToString error =
    case error of
        TimeZone.Json.NoZoneName ->
            "Couldn't get zone name"

        TimeZone.Json.HttpError zoneName httpError ->
            "Couldn't fetch zone data for '" ++ zoneName ++ "'"
