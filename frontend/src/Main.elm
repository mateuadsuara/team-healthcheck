port module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http exposing (..)
import Json.Decode exposing (Decoder, at, decodeString, int, list, map, map2, map3, map4, map5, nullable, string)
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


type alias MetricGoodCriteria =
    String


type alias MetricBadCriteria =
    String


type alias Metric =
    { name : MetricName
    , criteria : MetricCriteria
    , good_criteria : MetricGoodCriteria
    , bad_criteria : MetricBadCriteria
    , points_of_view : List PointOfView
    }


metricDecoder : Decoder Metric
metricDecoder =
    map5 Metric
        (at [ "name" ] string)
        (at [ "criteria" ] string)
        (at [ "good_criteria" ] string)
        (at [ "bad_criteria" ] string)
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
    = Admin
    | DataManagement
    | Username


type alias Rating =
    { health : Range
    , slope : Range
    }


type alias Model =
    { flags : Flags
    , snapshotState : SnapshotState
    , websocketState : WebsocketState
    , currentPage : Page
    , selectedRating : Rating
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
    | ChangedHealth String
    | ChangedSlope String


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
    Admin


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
      , selectedRating =
            initialRating
      }
    , Http.get
        { url = "/snapshot"
        , expect = Http.expectString GotSnapshot
        }
    )


initialRating : Rating
initialRating =
    { health = 0
    , slope = 0
    }


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
                                        [ h1 [] [ text "Add metrics:" ]
                                        , viewMetricForm
                                        , h1 [] [ text "View data:" ]
                                        , viewGraph snapshot.graph
                                        , h1 [] [ text "Manage data:" ]
                                        , span [ class "red" ] [ text "Warning: the format of this data is subject to change in the future." ]
                                        , h4 [] [ text "Export:" ]
                                        , viewExportLink
                                        , h4 [] [ text "Restore:" ]
                                        , viewRestoreForm
                                        ]
                                    ]

                            Admin ->
                                div []
                                    [ viewNavigationLinks model
                                    , div [ class "ph3 pv3" ] [ viewSelectMetric snapshot ]
                                    , div [ class "ph3 pv3" ] [ viewPeopleRegisteredActiveMetric model ]
                                    ]

                    else
                        case currentPage of
                            Username ->
                                viewUsername model

                            _ ->
                                div []
                                    [ viewTopbar model
                                    , div [ class "ph3" ] [ viewPointOfViewForm model ]
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
            [ a [ onClick (SetPage Admin), classesForPage Admin ] [ text "Admin" ]
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
                    [ text (metric.name ++ " [health: " ++ String.fromFloat (calculateAverageRange <| extractHealths metric.points_of_view) ++ ", slope: " ++ String.fromFloat (calculateAverageRange <| extractSlopes metric.points_of_view) ++ "]")
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
            (\pov -> li [] [ text (pov.date ++ " - " ++ pov.person ++ " " ++ povRatingString pov) ])
            povs
        )


povRatingString : PointOfView -> String
povRatingString pov =
    "[health: " ++ rangeToString pov.health ++ ", slope: " ++ rangeToString pov.slope ++ "]"


rangeToString : Range -> String
rangeToString rangeValue =
    String.fromFloat (absRange rangeValue)


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
        [ label [ for "name" ]
            [ text "The "
            , span [ class "blue" ] [ text "subject" ]
            , text " you'd like perspectives on:"
            ]
        , br [] []
        , input [ class "w-100", type_ "text", id "name", name "name", placeholder "e.g: Learning", required True ] []
        , br [] []
        , br [] []
        , label [ for "criteria" ]
            [ text " Ask a question about the "
            , span [ class "blue" ] [ text "subject" ]
            , text " to be answered with anything between "
            , span [ class "green" ] [ text "something positive" ]
            , text " and "
            , span [ class "red" ] [ text "something negative" ]
            , text ":"
            ]
        , br [] []
        , textarea [ class "w-100", id "criteria", name "criteria", placeholder "e.g: Are you learning?", required True ] []
        , br [] []
        , br [] []
        , label [ for "good_criteria" ]
            [ text "What does the "
            , span [ class "green" ] [ text "most positive (+1)" ]
            , text " answer look like?:"
            ]
        , br [] []
        , textarea [ class "w-100", id "good_criteria", name "good_criteria", placeholder "e.g: I am learning everyday!", required True ] []
        , br [] []
        , br [] []
        , label [ for "bad_criteria" ]
            [ text "What does the "
            , span [ class "red" ] [ text "most negative (-1)" ]
            , text " answer look like?:"
            ]
        , br [] []
        , textarea [ class "w-100", id "bad_criteria", name "bad_criteria", placeholder "e.g: I am not learning anything", required True ] []
        , br [] []
        , br [] []
        , input [ type_ "submit", value "Add Metric" ] []
        ]


getUsername : Model -> Username
getUsername model =
    Maybe.withDefault "" model.flags.username


type RatingValidation
    = Unchanged
    | SlopeCannotBeWorse
    | SlopeCannotBeBetter
    | ValidRerating
    | ValidRating


validateSelectedRating : Model -> RatingValidation
validateSelectedRating model =
    let
        isRated =
            case getActiveRating model of
                Nothing ->
                    False

                Just _ ->
                    True
    in
    if getActiveRating model == Just model.selectedRating then
        Unchanged

    else if model.selectedRating.health == maxRange && model.selectedRating.slope < 0 then
        SlopeCannotBeWorse

    else if model.selectedRating.health == (maxRange * -1) && model.selectedRating.slope > 0 then
        SlopeCannotBeBetter

    else if isRated then
        ValidRerating

    else
        ValidRating


viewPointOfViewForm : Model -> Html Message
viewPointOfViewForm model =
    let
        startDate =
            model.flags.startDate

        username =
            getUsername model

        activeMetric =
            getActiveMetric model

        selectedRating =
            model.selectedRating

        ratingValidation =
            validateSelectedRating model
    in
    case activeMetric of
        Nothing ->
            div [ class "tc" ] [ text "The faciliator is choosing what to do next..." ]

        Just metric ->
            div []
                [ div [ class "tc" ]
                    [ p []
                        [ text "We would like your perspective about "
                        , span [ class "blue" ] [ text metric.name ]
                        ]
                    , p [ class "f3-ns blue" ] [ text metric.criteria ]
                    ]
                , div []
                    [ span [] [ text <| "To broaden everyone's perspective about it, please:" ]
                    , ol []
                        [ li [ class "pv2" ]
                            [ span [] [ text <| "Share any facts you recall." ]

                            -- , ul []
                            --     [ li []
                            --         [ input [ class "", type_ "text" ] []
                            --         , input [ type_ "button", value "Share" ] []
                            --         ]
                            --     , li [] [ text "fact 1" ]
                            --     , li [] [ text "fact 2" ]
                            --     , li [] [ text "fact 3" ]
                            --     , li [] [ text "fact 4" ]
                            --     ]
                            ]
                        , li [ class "pv2" ]
                            [ span [] [ text <| "Maybe have a chat about the situation?" ]
                            ]
                        ]
                    ]
                , Html.form [ method "post", action "/register_point_of_view" ]
                    [ input [ type_ "date", name "date", value <| startDateForInput startDate, required True, hidden True ] []
                    , input [ type_ "text", name "person", value <| username, required True, hidden True ] []
                    , input [ type_ "text", name "metric_name", value metric.name, required True, hidden True ] []
                    , div [ class "fl w-100 tc" ]
                        [ label [ class "f4-ns", for "health" ] [ text "Current situation: " ]
                        ]
                    , div [ class "fl w-100 tc pv3" ]
                        [ div [ class "fl w-third v-mid tr red" ] [ text metric.bad_criteria ]
                        , viewSlider "health" selectedRating.health ChangedHealth [ class "fl w-third" ]
                        , div [ class "fl w-third v-mid tl green" ] [ text metric.good_criteria ]
                        ]
                    , div [ class "fl w-100 tc" ]
                        [ label [ class "f4-ns", for "slope" ] [ text "Now compared to before: " ]
                        ]
                    , div [ class "fl w-100 tc pv3" ]
                        [ div [ class "fl w-third tr red" ] [ text "worse" ]
                        , viewSlider "slope" selectedRating.slope ChangedSlope [ class "fl w-third" ]
                        , div [ class "fl w-third tl green" ] [ text "better" ]
                        ]
                    , div [ class "fl w-100 tc" ]
                        (case ratingValidation of
                            Unchanged ->
                                []

                            SlopeCannotBeWorse ->
                                [ span [ class "red" ] [ text "The current situation cannot not be worse!" ] ]

                            SlopeCannotBeBetter ->
                                [ span [ class "red" ] [ text "The current situation cannot not be better!" ] ]

                            ValidRerating ->
                                [ input [ type_ "submit", value <| "I changed my mind, I see it like this now" ] [] ]

                            ValidRating ->
                                [ input [ type_ "submit", value <| "That's how I see it" ] [] ]
                        )
                    ]
                ]


getActiveMetric : Model -> Maybe Metric
getActiveMetric model =
    case model.snapshotState of
        Loaded snapshot ->
            Maybe.andThen
                (\metric_name -> List.filter (\m -> m.name == metric_name) snapshot.graph |> List.head)
                snapshot.coordination.active_metric

        _ ->
            Nothing


getActiveRating : Model -> Maybe Rating
getActiveRating model =
    case model.flags.username of
        Just username ->
            case getActiveMetric model of
                Just metric ->
                    List.filter (\pov -> pov.person == username) metric.points_of_view |> List.head |> Maybe.map (\pov -> { slope = pov.slope, health = pov.health })

                _ ->
                    Nothing

        _ ->
            Nothing


viewSlider : String -> Range -> (String -> msg) -> List (Attribute msg) -> Html msg
viewSlider idName val message attributes =
    div attributes
        [ input [ class "w-90 v-mid", type_ "range", id idName, name idName, Html.Attributes.min ("-" ++ String.fromInt maxRange), Html.Attributes.max (String.fromInt maxRange), value <| String.fromInt val, Html.Attributes.list <| idName ++ "_data", required True, onInput message ]
            []
        , datalist [ id <| idName ++ "_data" ]
            [ option [ value "-4" ] []
            , option [ value "-2" ] []
            , option [ value "0" ] []
            , option [ value "2" ] []
            , option [ value "4" ] []
            ]
        ]


viewSelectMetric : Snapshot -> Html Message
viewSelectMetric snapshot =
    div []
        [ label [ for "metric_name" ] [ text "Metric to ask for input: " ]
        , viewDropdown [ id "metric_name", name "metric_name", required True ] (\metric -> { value = metric.name, text = metric.name, selected = Just metric.name == snapshot.coordination.active_metric }) ChangeActiveMetric snapshot.graph
        ]


viewPeopleRegisteredActiveMetric : Model -> Html Message
viewPeopleRegisteredActiveMetric model =
    case getActiveMetric model of
        Nothing ->
            div [] []

        Just activeMetric ->
            let
                people =
                    activeMetric.points_of_view
            in
            div []
                [ span [] [ text <| "People who submitted their perspective (" ++ (String.fromInt <| List.length people) ++ "):" ]
                , ul [] <|
                    List.map
                        (\pov -> li [] [ text <| pov.person ++ " " ++ povRatingString pov ])
                        people
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


updateRating : Model -> Model
updateRating model =
    let
        updatedRating =
            Maybe.withDefault initialRating <| getActiveRating model
    in
    { model | selectedRating = updatedRating }


update : Message -> Model -> ( Model, Cmd Message )
update msg model =
    case msg of
        GotSnapshot result ->
            ( updateRating { model | snapshotState = updateSnapshotState result model }, Cmd.none )

        UpdatedWebsocket stateString ->
            case parseWebsocketState stateString of
                Just state ->
                    ( { model | websocketState = state }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        UpdatedGraph graph ->
            ( updateRating { model | snapshotState = mapSnapshot model.snapshotState (\snapshot -> { snapshot | graph = graph }) }, Cmd.none )

        UpdatedCoordination coordination ->
            let
                modelUpdatedWithCoordination =
                    { model | snapshotState = mapSnapshot model.snapshotState (\snapshot -> { snapshot | coordination = coordination }) }
            in
            ( updateRating modelUpdatedWithCoordination, Cmd.none )

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
                ( { model | currentPage = Admin }, Cmd.none )

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

        ChangedHealth str ->
            let
                maybeRange =
                    String.toInt str

                selectedRating =
                    model.selectedRating

                updatedRating =
                    case maybeRange of
                        Nothing ->
                            selectedRating

                        Just range ->
                            { selectedRating | health = range }
            in
            ( { model | selectedRating = updatedRating }, Cmd.none )

        ChangedSlope str ->
            let
                maybeRange =
                    String.toInt str

                selectedRating =
                    model.selectedRating

                updatedRating =
                    case maybeRange of
                        Nothing ->
                            selectedRating

                        Just range ->
                            { selectedRating | slope = range }
            in
            ( { model | selectedRating = updatedRating }, Cmd.none )


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
