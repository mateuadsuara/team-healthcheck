port module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http exposing (..)
import Json.Decode exposing (Decoder, at, decodeString, int, list, map, map2, map3, map4, nullable, string)
import Time


port saveUsername : Username -> Cmd msg


port updatedGraph : (Graph -> msg) -> Sub msg


port updatedCoordination : (Coordination -> msg) -> Sub msg


port updatedWebsocket : (String -> msg) -> Sub msg


subscriptions : Model -> Sub Message
subscriptions model =
    Sub.batch
        [ updatedGraph UpdatedGraph
        , updatedCoordination UpdatedCoordination
        , updatedWebsocket UpdatedWebsocket
        ]


type alias Range =
    Int


maxRange =
    4


type alias PointOfView =
    { date : String --Time.Posix
    , person : String
    , health : Range
    , slope : Range
    }


pointOfViewDecoder : Decoder PointOfView
pointOfViewDecoder =
    map4 PointOfView
        (at [ "date" ] string)
        (at [ "person" ] string)
        (at [ "health" ] int)
        (at [ "slope" ] int)


type alias MetricName =
    String


type alias MetricCriteria =
    String


type alias Metric =
    { name : MetricName
    , criteria : MetricCriteria
    , points_of_view : List PointOfView
    }


metricDecoder : Decoder Metric
metricDecoder =
    map3 Metric
        (at [ "name" ] string)
        (at [ "criteria" ] string)
        (at [ "points_of_view" ] (list pointOfViewDecoder))


type alias Graph =
    List Metric


graphDecoder : Decoder Graph
graphDecoder =
    list metricDecoder


type alias Coordination =
    { active_metric : Maybe MetricName
    }


coordinationDecoder : Decoder Coordination
coordinationDecoder =
    map Coordination
        (at [ "active_metric" ] (nullable string))


type alias Snapshot =
    { graph : Graph
    , coordination : Coordination
    }


snapshotDecoder : Decoder Snapshot
snapshotDecoder =
    map2 Snapshot
        (at [ "graph" ] graphDecoder)
        (at [ "coordination" ] coordinationDecoder)


type alias StartDate =
    { year : Int
    , month : Int
    , day : Int
    }


type alias Flags =
    { startDate : StartDate
    , username : Maybe Username
    , admin : Bool
    }


type LoadError
    = ConnectionProblem
    | MalformedPayload


type SnapshotState
    = Loading
    | Failed LoadError
    | Loaded Snapshot


type WebsocketState
    = Connecting
    | Connected
    | Disconnected
    | Error


type Page
    = PointsOfView
    | Metrics
    | DataManagement
    | Username


type alias Model =
    { flags : Flags
    , snapshotState : SnapshotState
    , websocketState : WebsocketState
    , currentPage : Page
    }


type alias HttpResult =
    Result Http.Error String


type alias Username =
    String


type Message
    = GotSnapshot HttpResult
    | UpdatedWebsocket String
    | SetPage Page
    | SaveUsername Username
    | ChangedActiveMetric (Result Http.Error ())
    | ChangeActiveMetric MetricName
    | CompleteUsername
    | UpdatedGraph Graph
    | UpdatedCoordination Coordination


main : Program Flags Model Message
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


initialPage : Page
initialPage =
    PointsOfView


init : Flags -> ( Model, Cmd Message )
init flags =
    ( { flags = flags
      , snapshotState = Loading
      , websocketState = Connecting
      , currentPage =
            if flags.username == Nothing then
                Username

            else
                initialPage
      }
    , Http.get
        { url = "/snapshot"
        , expect = Http.expectString GotSnapshot
        }
    )


view : Model -> Html Message
view ({ snapshotState, websocketState, flags, currentPage } as model) =
    case snapshotState of
        Loading ->
            text "Loading..."

        Failed ConnectionProblem ->
            text "Failed loading! :( Check your connection and try reloading"

        Failed MalformedPayload ->
            text "Oops, we got a problem with the data we received. We need to fix this. Sorry for the inconvenience."

        Loaded snapshot ->
            case websocketState of
                Connecting ->
                    text "Connecting websocket..."

                Error ->
                    text "Failed websocket! :( Check your connection and try reloading"

                Disconnected ->
                    text "You got disconnected! :( I am trying to reconnect..."

                Connected ->
                    if flags.admin then
                        case currentPage of
                            Username ->
                                viewUsername model

                            DataManagement ->
                                div []
                                    [ viewNavigationLinks model
                                    , div [ class "ph3" ]
                                        [ h1 [] [ text "View data:" ]
                                        , viewGraph snapshot.graph
                                        , h1 [] [ text "Manage data:" ]
                                        , text "Warning: the format of this data is subject to change in the future."
                                        , h4 [] [ text "Export:" ]
                                        , viewExportLink
                                        , h4 [] [ text "Restore:" ]
                                        , viewRestoreForm
                                        ]
                                    ]

                            Metrics ->
                                div []
                                    [ viewNavigationLinks model
                                    , div [ class "ph3" ] [ viewMetricForm ]
                                    ]

                            PointsOfView ->
                                div []
                                    [ viewNavigationLinks model
                                    , div [ class "ph3" ] [ viewSelectMetric snapshot ]
                                    ]

                    else
                        case currentPage of
                            Username ->
                                viewUsername model

                            _ ->
                                div []
                                    [ viewTopbar model
                                    , div [ class "ph3" ] [ viewPointOfViewForm snapshot flags.startDate (getUsername model) ]
                                    ]


pageColor : Model -> Page -> String
pageColor model page =
    if model.currentPage == page then
        " light-blue bold"

    else
        " blue hover-light-blue"


viewTopbar : Model -> Html Message
viewTopbar model =
    let
        classesForPage page =
            class <| "pr4 pointer" ++ pageColor model page
    in
    div [ class "flex justify-between blue w-100 pb3 pa3 bb mb3" ]
        [ div [] []
        , a [ onClick (SetPage Username), class "pointer hover-light-blue" ] [ text <| getUsername model ]
        ]


viewNavigationLinks : Model -> Html Message
viewNavigationLinks model =
    let
        classesForPage page =
            class <| "pr4 pointer" ++ pageColor model page
    in
    div [ class "flex justify-between blue w-100 pb3 pa3 bb mb3" ]
        [ div []
            [ a [ onClick (SetPage PointsOfView), classesForPage PointsOfView ] [ text "Points of view" ]
            , a [ onClick (SetPage Metrics), classesForPage Metrics ] [ text "Metrics" ]
            , a [ onClick (SetPage DataManagement), classesForPage DataManagement ] [ text "DataManagement" ]
            ]
        , a [ onClick (SetPage Username), class "pointer hover-light-blue" ] [ text <| getUsername model ]
        ]


viewUsername : Model -> Html Message
viewUsername model =
    let
        username =
            Maybe.withDefault "" model.flags.username
    in
    Html.form [ class "tc ph3", onSubmit CompleteUsername ]
        [ p [] [ text "Hi!👋😃" ]
        , p [] [ text "Welcome to the team healthcheck!" ]
        , p [] [ text "What's your name?" ]
        , input [ type_ "text", class "", placeholder "Your name", onInput SaveUsername, value username ] []
        , input [ type_ "submit", value "Done" ] []
        ]


viewGraph : Graph -> Html Message
viewGraph graph =
    ul []
        (List.map
            (\metric ->
                li []
                    [ text (metric.name ++ " (" ++ metric.criteria ++ ")" ++ " [health: " ++ String.fromFloat (calculateAverageRange <| extractHealths metric.points_of_view) ++ ", slope: " ++ String.fromFloat (calculateAverageRange <| extractSlopes metric.points_of_view) ++ "]")
                    , viewPointsOfView metric.points_of_view
                    ]
            )
            graph
        )


extractHealths : List PointOfView -> List Range
extractHealths povs =
    List.map (\pov -> pov.health) povs


extractSlopes : List PointOfView -> List Range
extractSlopes povs =
    List.map (\pov -> pov.slope) povs


calculateAverageRange : List Range -> Float
calculateAverageRange nums =
    let
        count =
            List.length nums

        absNums =
            List.map (\n -> absRange n) nums

        average =
            List.sum absNums / toFloat count
    in
    if count == 0 then
        0

    else
        average


absRange : Int -> Float
absRange rangeValue =
    toFloat rangeValue / maxRange


viewPointsOfView : List PointOfView -> Html Message
viewPointsOfView povs =
    ul []
        (List.map
            (\pov -> li [] [ text (pov.date ++ " [health: " ++ String.fromFloat (absRange pov.health) ++ ", slope: " ++ String.fromFloat (absRange pov.slope) ++ "] ") ])
            povs
        )


viewExportLink : Html Message
viewExportLink =
    a [ href "/serialise", download "export.json" ]
        [ text "Export" ]


viewRestoreForm : Html Message
viewRestoreForm =
    Html.form [ method "post", action "/deserialise", enctype "multipart/form-data" ]
        [ input [ type_ "file", name "serialised", required True ] []
        , input [ type_ "submit", value "Restore" ] []
        ]


viewMetricForm : Html Message
viewMetricForm =
    Html.form [ method "post", action "/add_metric" ]
        [ label [ for "name" ] [ text "We are looking for perspectives on: " ]
        , br [] []
        , input [ type_ "text", id "name", name "name", placeholder "Name", required True ] []
        , br [] []
        , br [] []
        , label [ for "criteria" ]
            [ text "In order for everyone to be on the same page, the guidelines to be considered on how to rate it are:"
            , br [] []
            , span [ class "gray" ] [ text "(remember to define what a " ]
            , span [ class "red" ] [ text "-1" ]
            , span [ class "gray" ] [ text " means and what " ]
            , span [ class "green" ] [ text "+1" ]
            , span [ class "gray" ] [ text " would mean for the current situation --aka health-- and for comparing with before --aka slope--)" ]
            ]
        , br [] []
        , textarea [ class "w-100", id "criteria", name "criteria", placeholder "Criteria", required True ] []
        , br [] []
        , br [] []
        , input [ type_ "submit", value "Add Metric" ] []
        ]


getUsername : Model -> Username
getUsername model =
    Maybe.withDefault "" model.flags.username


viewPointOfViewForm : Snapshot -> StartDate -> Username -> Html Message
viewPointOfViewForm snapshot startDate username =
    case getActiveMetric snapshot of
        Nothing ->
            text "The faciliator is choosing what to do next..."

        Just metric ->
            div []
                [ div [ class "tc" ]
                    [ p [ class "f4-ns" ] [ text "We would like your perspective about: " ]
                    , p [ class "blue" ] [ text metric.name ]
                    ]
                , br [] []
                , br [] []
                , br [] []
                , span [] [ text <| "In order for everyone to be on the same page, please:" ]
                , ol [ class "" ]
                    [ li []
                        [ span [] [ text <| "Consider the following on how to rate it:" ]
                        , br [] []
                        , span [ class "blue" ] [ text metric.criteria ]
                        ]
                    , br [] []
                    , li []
                        [ span [] [ text <| "Have a conversation about the facts you can recall. " ]
                        , br [] []
                        , span [ class "gray" ] [ text <| "(This will hopefully give everyone a broader perspective on the subject)" ]
                        ]
                    ]
                , br [] []
                , br [] []
                , br [] []
                , Html.form [ method "post", action "/register_point_of_view" ]
                    [ input [ type_ "date", name "date", value <| startDateForInput startDate, required True, hidden True ] []
                    , input [ type_ "text", name "person", value <| username, required True, hidden True ] []
                    , input [ type_ "text", name "metric_name", value metric.name, required True, hidden True ] []
                    , div [ class "tc" ]
                        [ label [ class "f4-ns", for "health" ] [ text "Current situation: " ]
                        , br [] []
                        , br [] []
                        , span [ class "red" ] [ text " (-1) bad " ]
                        , input [ type_ "range", id "health", name "health", Html.Attributes.min ("-" ++ String.fromInt maxRange), Html.Attributes.max (String.fromInt maxRange), value "0", required True ] []
                        , span [ class "green" ] [ text " good (+1)" ]
                        ]
                    , br [] []
                    , br [] []
                    , div [ class "tc" ]
                        [ label [ class "f4-ns", for "slope" ] [ text "Now compared to before: " ]
                        , br [] []
                        , br [] []
                        , span [ class "red" ] [ text " (-1) ⇘ worse " ]
                        , input [ type_ "range", id "slope", name "slope", Html.Attributes.min ("-" ++ String.fromInt maxRange), Html.Attributes.max (String.fromInt maxRange), value "0", required True ] []
                        , span [ class "green" ] [ text " better ⇗ (+1)" ]
                        ]
                    , br [] []
                    , br [] []
                    , div [ class "tc" ] [ input [ type_ "submit", value "That's how I see it" ] [] ]
                    ]
                ]


getActiveMetric : Snapshot -> Maybe Metric
getActiveMetric snapshot =
    case snapshot.coordination.active_metric of
        Nothing ->
            Nothing

        Just metric_name ->
            List.filter (\m -> m.name == metric_name) snapshot.graph |> List.head


viewSelectMetric : Snapshot -> Html Message
viewSelectMetric snapshot =
    div []
        [ label [ for "metric_name" ] [ text "Metric for input: " ]
        , viewDropdown [ id "metric_name", name "metric_name", required True ] (\metric -> { value = metric.name, text = metric.name, selected = Just metric.name == snapshot.coordination.active_metric }) ChangeActiveMetric snapshot.graph
        ]


startDateForInput : StartDate -> String
startDateForInput { year, month, day } =
    leftZeroesPadding year ++ "-" ++ leftZeroesPadding month ++ "-" ++ leftZeroesPadding day


leftZeroesPadding : Int -> String
leftZeroesPadding num =
    let
        input =
            String.fromInt num
    in
    if String.length input == 1 then
        "0" ++ input

    else
        input


viewDropdown : List (Attribute msg) -> (e -> { value : String, text : String, selected : Bool }) -> (String -> msg) -> List e -> Html msg
viewDropdown attrs optionFn onChangeMessage options =
    select
        (attrs
            ++ [ onInput onChangeMessage ]
        )
    <|
        [ option [] [] ]
            ++ List.map
                (\e -> option [ value (optionFn e).value, selected (optionFn e).selected ] [ text (optionFn e).text ])
                options


update : Message -> Model -> ( Model, Cmd Message )
update msg model =
    case msg of
        GotSnapshot result ->
            ( { model | snapshotState = updateSnapshotState result model }, Cmd.none )

        UpdatedWebsocket stateString ->
            case parseWebsocketState stateString of
                Just state ->
                    ( { model | websocketState = state }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        UpdatedGraph graph ->
            ( { model | snapshotState = mapSnapshot model.snapshotState (\snapshot -> { snapshot | graph = graph }) }, Cmd.none )

        UpdatedCoordination coordination ->
            ( { model | snapshotState = mapSnapshot model.snapshotState (\snapshot -> { snapshot | coordination = coordination }) }, Cmd.none )

        SetPage page ->
            ( { model | currentPage = page }, Cmd.none )

        SaveUsername username ->
            let
                flags =
                    model.flags

                trimmedUsername =
                    String.trim username
            in
            case trimmedUsername of
                "" ->
                    ( { model | flags = { flags | username = Nothing } }, saveUsername "" )

                _ ->
                    ( { model | flags = { flags | username = Just trimmedUsername } }, saveUsername trimmedUsername )

        CompleteUsername ->
            if model.flags.username == Nothing then
                ( { model | currentPage = Username }, Cmd.none )

            else
                ( { model | currentPage = PointsOfView }, Cmd.none )

        ChangeActiveMetric activeMetric ->
            ( model
            , Http.post
                { url = "/set_active_metric"
                , expect = expectWhatever ChangedActiveMetric
                , body =
                    multipartBody
                        [ stringPart "active_metric" activeMetric
                        ]
                }
            )

        ChangedActiveMetric _ ->
            ( model, Cmd.none )


mapSnapshot : SnapshotState -> (Snapshot -> Snapshot) -> SnapshotState
mapSnapshot snapshotState updateFn =
    case snapshotState of
        Loading ->
            snapshotState

        Failed _ ->
            snapshotState

        Loaded snapshot ->
            Loaded <| updateFn snapshot


updateSnapshotState : HttpResult -> Model -> SnapshotState
updateSnapshotState result model =
    case result of
        Ok json ->
            case decodeString snapshotDecoder json of
                Ok snapshot ->
                    Loaded snapshot

                Err _ ->
                    Failed MalformedPayload

        Err _ ->
            Failed ConnectionProblem


parseWebsocketState : String -> Maybe WebsocketState
parseWebsocketState stateString =
    case stateString of
        "connected" ->
            Just Connected

        "disconnected" ->
            Just Disconnected

        "reconnected" ->
            Just Connected

        "error" ->
            Just Error

        _ ->
            Nothing
