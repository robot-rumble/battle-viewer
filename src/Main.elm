module Main exposing (..)

import Browser
import Browser.Dom
import Browser.Events
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Task
import Url



-- MAIN


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- MODEL


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , width : Int
    }


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    (Model key url 0, Task.perform InitialViewport Browser.Dom.getViewport )



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | Resized Int Int
    | InitialViewport Browser.Dom.Viewport

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | url = url }, Cmd.none )

        Resized width height ->
            ( { model | width = width }, Cmd.none )

        InitialViewport viewport ->
            ( { model | width = truncate viewport.viewport.width }, Cmd.none)



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Browser.Events.onResize Resized



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Copala"
    , body =
        [div [] [text "hello!"]
        ]
    }


