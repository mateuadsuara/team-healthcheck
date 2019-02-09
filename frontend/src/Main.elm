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
    }


type LoadError
    = ConnectionProblem
    | MalformedPayload


type GraphState
    = Loading
    | Failed LoadError
    | Loaded { graph : Graph }


type alias Model =
    { flags : Flags
    , graphState : GraphState
    }


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
    ( { flags = flags
      , graphState = Loading
      }
    , Http.get
        { url = "/graph"
        , expect = Http.expectString GotGraph
        }
    )


view : Model -> Html Message
view { graphState, flags } =
    case graphState of
        Loading ->
            text "Loading..."

        Failed ConnectionProblem ->
            text "Failed loading! :( Check your connection and try reloading"

        Failed MalformedPayload ->
            text "Oops, we got a problem with the data we received. We need to fix this. Sorry for the inconvenience."

        Loaded { graph } ->
            div []
                [ viewPointOfViewForm graph flags.startDate
                , viewMetricForm
                , h1 [] [ text "Metrics:" ]
                , viewGraph graph
                , viewExportLink
                , viewImportForm
                ]


viewGraph : Graph -> Html Message
viewGraph graph =
    ul []
        (List.map
            (\metric ->
                li []
                    [ text (metric.name ++ " (" ++ metric.criteria ++ ")")
                    , viewPointsOfView metric.points_of_view
                    ]
            )
            graph
        )


viewPointsOfView : List PointOfView -> Html Message
viewPointsOfView povs =
    ul []
        (List.map
            (\pov -> li [] [ text (pov.date ++ " > " ++ String.fromInt pov.health ++ " : " ++ String.fromInt pov.slope) ])
            povs
        )


viewExportLink : Html Message
viewExportLink =
    a [ href "/serialise", download "export.json" ]
        [ text "Export" ]


viewImportForm : Html Message
viewImportForm =
    Html.form [ method "post", action "/deserialise", enctype "multipart/form-data" ]
        [ input [ type_ "file", name "serialised", required True ] []
        , input [ type_ "submit", value "Import" ] []
        ]


viewMetricForm : Html Message
viewMetricForm =
    Html.form [ method "post", action "/add_metric" ]
        [ input [ type_ "text", name "name", placeholder "Name", required True ] []
        , input [ type_ "text", name "criteria", placeholder "Criteria", required True ] []
        , input [ type_ "submit", value "Add Metric" ] []
        ]


viewPointOfViewForm : Graph -> StartDate -> Html Message
viewPointOfViewForm graph startDate =
    Html.form [ method "post", action "/register_point_of_view" ]
        [ viewDropdown [ name "metric_name", required True ] (\metric -> { value = metric.name, text = metric.name }) graph
        , input [ type_ "date", name "date", value <| startDateForInput startDate, required True ] []
        , input [ type_ "text", name "person", placeholder "Person", required True ] []
        , input [ type_ "range", name "health", Html.Attributes.min "-2", Html.Attributes.max "2", value "0", required True ] []
        , input [ type_ "range", name "slope", Html.Attributes.min "-2", Html.Attributes.max "2", value "0", required True ] []
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
    ( { model | graphState = updateGraphState msg model }, Cmd.none )


updateGraphState : Message -> Model -> GraphState
updateGraphState msg model =
    case msg of
        GotGraph (Ok json) ->
            case decodeString graphDecoder json of
                Ok graph ->
                    Loaded { graph = graph }

                Err _ ->
                    Failed MalformedPayload

        GotGraph (Err _) ->
            Failed ConnectionProblem


subscriptions : Model -> Sub Message
subscriptions model =
    Sub.none
