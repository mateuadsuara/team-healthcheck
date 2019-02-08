module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput)
import Http
import Json.Decode exposing (Decoder, at, decodeString, int, list, map3, map4, string)
import Time


type alias Range =
    Int


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


type alias MetricToAdd =
    { name : MetricName
    , criteria : MetricCriteria
    }


type alias Graph =
    List Metric


graphDecoder : Decoder Graph
graphDecoder =
    list metricDecoder


type alias Flags =
    Bool


type LoadError
    = ConnectionProblem
    | MalformedPayload


type Model
    = Loading
    | Failed LoadError
    | Loaded { graph : Graph, metricToAdd : MetricToAdd }


type Message
    = GotGraph (Result Http.Error String)


main : Program Flags Model Message
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


init : Flags -> ( Model, Cmd Message )
init flags =
    ( Loading
    , Http.get
        { url = "/graph"
        , expect = Http.expectString GotGraph
        }
    )


initMetricToAdd : MetricToAdd
initMetricToAdd =
    { name = "", criteria = "" }


view : Model -> Html Message
view model =
    case model of
        Loading ->
            text "Loading..."

        Failed ConnectionProblem ->
            text "Failed loading! :( Check your connection and try reloading"

        Failed MalformedPayload ->
            text "Oops, we got a problem with the data we received. We need to fix this. Sorry for the inconvenience."

        Loaded { graph, metricToAdd } ->
            div []
                [ viewMetricForm metricToAdd
                , h1 [] [ text "Metrics:" ]
                , viewGraph graph
                , viewPointOfViewForm graph
                ]


viewGraph : Graph -> Html Message
viewGraph graph =
    div []
        [ ul []
            (List.map
                (\metric -> li [] [ text (metric.name ++ " - " ++ metric.criteria) ])
                graph
            )
        ]


viewMetricForm : MetricToAdd -> Html Message
viewMetricForm metricToAdd =
    Html.form [ method "post", action "/add_metric" ]
        [ input [ type_ "text", name "name", placeholder "Name", value metricToAdd.name, required True ] []
        , input [ type_ "text", name "criteria", placeholder "Criteria", value metricToAdd.criteria, required True ] []
        , input [ type_ "submit", value "Add Metric" ] []
        ]


viewPointOfViewForm : Graph -> Html Message
viewPointOfViewForm graph =
    Html.form [ method "post", action "/register_point_of_view" ]
        [ viewDropdown [ name "metric_name", required True ] (\metric -> { value = metric.name, text = metric.name }) graph
        , input [ type_ "date", name "date", required True ] []
        , input [ type_ "text", name "person", placeholder "Person", required True ] []
        , input [ type_ "range", name "health", Html.Attributes.min "-2", Html.Attributes.max "2", value "0", required True ] []
        , input [ type_ "range", name "slope", Html.Attributes.min "-2", Html.Attributes.max "2", value "0", required True ] []
        , input [ type_ "submit", value "Register Point Of View" ] []
        ]


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
        GotGraph (Ok json) ->
            case decodeString graphDecoder json of
                Ok graph ->
                    ( Loaded { graph = graph, metricToAdd = initMetricToAdd }, Cmd.none )

                Err _ ->
                    ( Failed MalformedPayload, Cmd.none )

        GotGraph (Err _) ->
            ( Failed ConnectionProblem, Cmd.none )


subscriptions : Model -> Sub Message
subscriptions model =
    Sub.none
