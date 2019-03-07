import Browser
import Html exposing (Html, button, div, text)
import Html.Events exposing (onClick)

import LocalServer
import ServerData as D

import DOMRenderer
import View

main =
  Debug.log(D.packetToString LocalServer.p)
  Browser.sandbox { init = init, update = update, view = view }


-- MODEL

type alias Model = Int

init : Model
init =
  0

-- UPDATE

type Msg = Increment | Decrement

update : Msg -> Model -> Model
update msg model =
  case msg of
    Increment ->
      model + 1

    Decrement ->
      model - 1


-- VIEW

view : Model -> Html Msg
view model =
  div []
    [ 
      View.code
      DOMRenderer.field LocalServer.p 
      View.info
    ]
