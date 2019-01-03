module Main exposing (main)

import Browser
import Html exposing (Html, div, text)


type alias Flags =
    Bool


type Model
    = NoModel


type Message
    = NoMessage


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
    ( NoModel, Cmd.none )


view : Model -> Html Message
view model =
    div []
        []


update : Message -> Model -> ( Model, Cmd Message )
update msg model =
    case msg of
        NoMessage ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Message
subscriptions model =
    Sub.none
