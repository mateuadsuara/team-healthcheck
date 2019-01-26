module Main exposing (main)

import Browser
import Html exposing (Html, div, text)
import Http
import Time


type alias Range =
    Int


type alias PointOfView =
    { date : Time.Posix
    , person : String
    , health : Range
    , slope : Range
    }


type alias Metric =
    { name : String
    , criteria : String
    , points_of_view : List PointOfView
    }


type alias Graph =
    List Metric


type alias Flags =
    Bool


type Model
    = Loading
    | Failed
    | Loaded { graph : String }


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

        Failed ->
            text "Failed loading! :( Try reloading the page"

        Loaded { graph } ->
            text graph


update : Message -> Model -> ( Model, Cmd Message )
update msg model =
    case msg of
        GotGraph (Ok graph) ->
            ( Loaded { graph = graph }, Cmd.none )

        GotGraph (Err _) ->
            ( Failed, Cmd.none )


subscriptions : Model -> Sub Message
subscriptions model =
    Sub.none
