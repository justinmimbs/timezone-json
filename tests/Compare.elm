module Compare exposing (main)

import Browser
import Dict exposing (Dict)
import Format exposing (formatPosix)
import Html exposing (Html)
import Html.Attributes
import Http
import Json.Decode as Decode exposing (Decoder, Value)
import Task exposing (Task)
import Time exposing (Posix)
import TimeZone.Json exposing (ZoneInfo)


main : Program ZoneInfo Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }


type alias Model =
    { js : ZoneInfo
    , tzResult : Result String ZoneInfo
    }


type Msg
    = ReceiveZoneInfo (Result String ZoneInfo)


init : ZoneInfo -> ( Model, Cmd Msg )
init zone =
    ( { js = zone
      , tzResult = Err "Loading"
      }
    , Time.getZoneName
        |> Task.andThen
            (\nameOrOffset ->
                case nameOrOffset of
                    Time.Name zoneName ->
                        TimeZone.Json.getZoneInfoByName "/dist/2019c/" zoneName
                            |> Task.mapError (\_ -> "Couldn't load time zone: " ++ zoneName)

                    Time.Offset offset ->
                        Task.fail "Couldn't get time zone name"
            )
        |> Task.attempt ReceiveZoneInfo
    )



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update (ReceiveZoneInfo result) model =
    ( { model | tzResult = result }
    , Cmd.none
    )



-- view


view : Model -> Browser.Document Msg
view { js, tzResult } =
    Browser.Document
        "Compare"
        (case tzResult of
            Err message ->
                [ Html.pre [] [ Html.text message ] ]

            Ok tz ->
                let
                    colWidth =
                        36

                    lines : List (Join String)
                    lines =
                        joinDicts
                            (indexChanges js.initial (List.reverse js.changes))
                            (indexChanges tz.initial (List.reverse tz.changes))
                            |> List.map Tuple.second

                    diffCount =
                        lines |> List.foldl (\line count -> (isMatch line |> bool 0 1) + count) 0

                    style =
                        Html.node "style" [] [ Html.text "pre { margin: 0; }" ]

                    desc =
                        Html.pre []
                            [ [ "Compare the offset changes used by your browser to those loaded for your"
                              , "local zone."
                              , ""
                              , ""
                              ]
                                |> String.join "\n"
                                |> Html.text
                            ]

                    summary =
                        Html.pre
                            [ Html.Attributes.style "color" (diffCount == 0 |> bool "limegreen" "red") ]
                            [ Html.text (String.fromInt diffCount ++ " difference" ++ (diffCount == 1 |> bool "" "s") ++ "\n\n") ]

                    headers : List (Html a)
                    headers =
                        List.map
                            (\text -> Html.pre [] [ Html.text text ])
                            [ (js.name |> String.left colWidth |> String.padRight colWidth ' ')
                                ++ " | "
                                ++ tz.name
                            , String.repeat colWidth "-"
                                ++ " | "
                                ++ String.repeat colWidth "-"
                            ]
                in
                style
                    :: desc
                    :: summary
                    :: headers
                    ++ (lines |> List.map (viewLine colWidth))
        )


viewLine : Int -> Join String -> Html a
viewLine colWidth line =
    let
        ( isDiff, text ) =
            case line of
                Left l ->
                    ( True, l ++ " | " )

                Right r ->
                    ( True, String.repeat colWidth " " ++ " | " ++ r )

                Both l r ->
                    ( l /= r, l ++ " | " ++ r )
    in
    Html.pre
        [ Html.Attributes.style "color" (isDiff |> bool "red" "gray") ]
        [ Html.text text ]


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
                        ++ "  ->  "
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
    (offset < 0 |> bool "-" "+")
        ++ (abs offset // 60 |> String.fromInt |> String.padLeft 2 '0')
        ++ ":"
        ++ (abs offset |> modBy 60 |> String.fromInt |> String.padLeft 2 '0')


type Join a
    = Left a
    | Right a
    | Both a a


isMatch : Join a -> Bool
isMatch x =
    case x of
        Left _ ->
            False

        Right _ ->
            False

        Both l r ->
            l == r


joinDicts : Dict comparable a -> Dict comparable a -> List ( comparable, Join a )
joinDicts left right =
    Dict.merge
        (\key l list -> ( key, Left l ) :: list)
        (\key l r list -> ( key, Both l r ) :: list)
        (\key r list -> ( key, Right r ) :: list)
        left
        right
        []


bool : a -> a -> Bool -> a
bool t f x =
    if x then
        t

    else
        f
