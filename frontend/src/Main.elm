module Main exposing (main)

import Browser
import Html exposing (Html, div, h1, li, text, ul)
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


type alias Metric =
    { name : String
    , criteria : String
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


type alias Flags =
    Bool


type LoadError
    = ConnectionProblem
    | MalformedPayload


type Model
    = Loading
    | Failed LoadError
    | Loaded { graph : Graph }


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


view : Model -> Html Message
view model =
    case model of
        Loading ->
            text "Loading..."

        Failed ConnectionProblem ->
            text "Failed loading! :( Check your connection and try reloading"

        Failed MalformedPayload ->
            text "Oops, we got a problem with the data we received. We need to fix this. Sorry for the inconvenience."

        Loaded { graph } ->
            viewGraph graph


viewGraph : Graph -> Html Message
viewGraph graph =
    div []
        [ h1 [] [ text "Metrics:" ]
        , ul []
            (List.map
                (\metric -> li [] [ text metric.name ])
                graph
            )
        ]


update : Message -> Model -> ( Model, Cmd Message )
update msg model =
    case msg of
        GotGraph (Ok json) ->
            case decodeString graphDecoder json of
                Ok graph ->
                    ( Loaded { graph = graph }, Cmd.none )

                Err _ ->
                    ( Failed MalformedPayload, Cmd.none )

        GotGraph (Err _) ->
            ( Failed ConnectionProblem, Cmd.none )


subscriptions : Model -> Sub Message
subscriptions model =
    Sub.none
