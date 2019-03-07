module DOMRenderer exposing (..)

import Html exposing (Html, div, p, text)
import Html.Attributes exposing (class, classList, property, style)
import ServerData as D
import Debug

field : D.Packet -> Html msg
field packet =
  div [ class "field" ]
    (List.map renderEntity packet.entities)

renderEntity : D.Entity -> Html msg
renderEntity entity = 
  div [ classList [(D.teamToString entity.team, True),
                   (D.actionToString entity.action, True),
                   (D.entityTypeToString entity.entityType, True)],
        style "top" ((String.fromInt (25*entity.position.y))++"px"),
        style "left" ((String.fromInt (25*entity.position.x))++"px")]
      [] 
