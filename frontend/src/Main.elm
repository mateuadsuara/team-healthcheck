port module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Json.Decode exposing (Decoder, at, decodeString, int, list, map3, map4, string)
import Time


port saveUsername : Username -> Cmd msg


port websocketPort : String -> Cmd msg


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


type alias StartDate =
    { year : Int
    , month : Int
    , day : Int
    }


type alias Flags =
    { startDate : StartDate
    , username : Maybe Username
    }


type LoadError
    = ConnectionProblem
    | MalformedPayload


type GraphState
    = Loading
    | Failed LoadError
    | Loaded { graph : Graph }


type Page
    = PointsOfView
    | Metrics
    | DataManagement
    | Websocket
    | Username


type alias Model =
    { flags : Flags
    , graphState : GraphState
    , currentPage : Page
    }


type alias HttpResult =
    Result Http.Error String


type alias Username =
    String


type Message
    = GotGraph HttpResult
    | SetPage Page
    | SaveUsername Username
    | CompletedUsername
    | WebsocketSend String


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
    Websocket


init : Flags -> ( Model, Cmd Message )
init flags =
    ( { flags = flags
      , graphState = Loading
      , currentPage =
            if flags.username == Nothing then
                Username

            else
                initialPage
      }
    , Http.get
        { url = "/graph"
        , expect = Http.expectString GotGraph
        }
    )


view : Model -> Html Message
view ({ graphState, flags, currentPage } as model) =
    case graphState of
        Loading ->
            text "Loading..."

        Failed ConnectionProblem ->
            text "Failed loading! :( Check your connection and try reloading"

        Failed MalformedPayload ->
            text "Oops, we got a problem with the data we received. We need to fix this. Sorry for the inconvenience."

        Loaded { graph } ->
            case currentPage of
                Username ->
                    viewUsername model

                DataManagement ->
                    div []
                        [ viewNavigationLinks model
                        , div [ class "ph3" ]
                            [ h1 [] [ text "View data:" ]
                            , viewGraph graph
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
                        , div [ class "ph3" ] [ viewPointOfViewForm graph flags.startDate (getUsername model) ]
                        ]

                Websocket ->
                    div []
                        [ viewNavigationLinks model
                        , div [ class "ph3" ] [ viewWebsocket model ]
                        ]


pageColor : Model -> Page -> String
pageColor model page =
    if model.currentPage == page then
        " light-blue bold"

    else
        " blue hover-light-blue"


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
            , a [ onClick (SetPage Websocket), classesForPage Websocket ] [ text "Websocket" ]
            ]
        , a [ onClick (SetPage Username), class "pointer hover-light-blue" ] [ text <| getUsername model ]
        ]


viewWebsocket : Model -> Html Message
viewWebsocket model =
    Html.form [ class "tc ph3" ]
        [ p [] [ text "Websocket!👋😃" ]
        , input [ type_ "text", class "", placeholder "String", onInput WebsocketSend, value "" ] []
        ]


viewUsername : Model -> Html Message
viewUsername model =
    let
        username =
            Maybe.withDefault "" model.flags.username
    in
    Html.form [ class "tc ph3" ]
        [ p [] [ text "Hi!👋😃" ]
        , p [] [ text "Welcome to the team healthcheck!" ]
        , p [] [ text "What's your name?" ]
        , input [ type_ "text", class "", placeholder "Your name", onInput SaveUsername, value username ] []
        , input [ type_ "submit", onSubmit CompletedUsername, value "Done" ] []
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
        [ label [ for "name" ] [ text "Name: " ]
        , input [ type_ "text", id "name", name "name", placeholder "Name", required True ] []
        , br [] []
        , label [ for "criteria" ] [ text "Criteria: " ]
        , input [ type_ "text", id "criteria", name "criteria", placeholder "Criteria", required True ] []
        , br [] []
        , input [ type_ "submit", value "Add Metric" ] []
        ]


getUsername : Model -> Username
getUsername model =
    Maybe.withDefault "" model.flags.username


viewPointOfViewForm : Graph -> StartDate -> Username -> Html Message
viewPointOfViewForm graph startDate username =
    Html.form [ method "post", action "/register_point_of_view" ]
        [ input [ type_ "date", name "date", value <| startDateForInput startDate, required True, hidden True ] []
        , input [ type_ "text", name "person", value <| username, required True, hidden True ] []
        , label [ for "metric_name" ] [ text "Metric: " ]
        , viewDropdown [ id "metric_name", name "metric_name", required True ] (\metric -> { value = metric.name, text = metric.name }) graph
        , br [] []
        , label [ for "health" ] [ text "Health: " ]
        , span [ class "red" ] [ text " (-1) bad " ]
        , input [ type_ "range", id "health", name "health", Html.Attributes.min ("-" ++ String.fromInt maxRange), Html.Attributes.max (String.fromInt maxRange), value "0", required True ] []
        , span [ class "green" ] [ text " good (+1)" ]
        , br [] []
        , label [ for "slope" ] [ text "Slope: " ]
        , text " (-1) ⇘ "
        , input [ type_ "range", id "slope", name "slope", Html.Attributes.min ("-" ++ String.fromInt maxRange), Html.Attributes.max (String.fromInt maxRange), value "0", required True ] []
        , text " ⇗ (+1)"
        , br [] []
        , input [ type_ "submit", value "Register Point Of View" ] []
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


viewDropdown : List (Attribute msg) -> (e -> { value : String, text : String }) -> List e -> Html msg
viewDropdown attrs optionFn options =
    select attrs
        (List.map
            (\e -> option [ value (optionFn e).value ] [ text (optionFn e).text ])
            options
        )


update : Message -> Model -> ( Model, Cmd Message )
update msg model =
    case msg of
        GotGraph result ->
            ( { model | graphState = updateGraphState result model }, Cmd.none )

        SetPage page ->
            ( { model | currentPage = page }, Cmd.none )

        SaveUsername username ->
            let
                flags =
                    model.flags

                updatedFlags =
                    { flags | username = Just username }
            in
            ( { model | flags = updatedFlags }, saveUsername username )

        CompletedUsername ->
            ( { model | currentPage = PointsOfView }, Cmd.none )

        WebsocketSend string ->
            ( model, websocketPort string )


updateGraphState : HttpResult -> Model -> GraphState
updateGraphState result model =
    case result of
        Ok json ->
            case decodeString graphDecoder json of
                Ok graph ->
                    Loaded { graph = graph }

                Err _ ->
                    Failed MalformedPayload

        Err _ ->
            Failed ConnectionProblem


subscriptions : Model -> Sub Message
subscriptions model =
    Sub.none
