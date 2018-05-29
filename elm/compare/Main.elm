module Main exposing (main)

import Browser
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes
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
    , tzResult : Result String TimeZone
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
      , tzResult = Err "Loading"
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
    ( { model | tzResult = result }
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
view { js, tzResult } =
    case tzResult of
        Err message ->
            Html.pre [] [ Html.text message ]

        Ok tz ->
            let
                colWidth =
                    31

                lines : List (Join String)
                lines =
                    joinDicts
                        (indexChanges js.initial (List.reverse js.changes))
                        (indexChanges tz.initial (List.reverse tz.changes))
                        |> List.map Tuple.second

                diffCount =
                    lines |> List.foldl (\line count -> (isMatch line |> bool 0 1) + count) 0

                style : Html a
                style =
                    Html.node "style" [] [ Html.text "pre { margin: 0; }" ]

                summary : Html a
                summary =
                    Html.pre
                        [ Html.Attributes.style "color" (diffCount == 0 |> bool "green" "red") ]
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
            Html.div [] (style :: summary :: headers ++ (lines |> List.map (viewLine colWidth)))


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
    (offset < 0 |> bool "-" "+")
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
