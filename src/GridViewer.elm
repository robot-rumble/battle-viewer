module GridViewer exposing (Model, Msg(..), init, update, view)

import Array exposing (Array)
import Data
import Grid
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)



-- MODEL


type alias Model =
    { turns : Array Data.TurnState
    , total_turns : Int
    , current_turn : Int
    }


init : Data.TurnState -> Int -> Model
init firstTurn totalTurns =
    Model (Array.fromList [ firstTurn ]) totalTurns 0



-- UPDATE


type Msg
    = ChangeTurn Direction
    | GotTurn Data.TurnState


type Direction
    = Next
    | Previous


update : Msg -> Model -> Model
update msg model =
    case msg of
        GotTurn turn ->
            { model | turns = Array.push turn model.turns }

        ChangeTurn dir ->
            { model
                | current_turn =
                    model.current_turn
                        + (case dir of
                            Next ->
                                if model.current_turn == Array.length model.turns - 1 then
                                    0

                                else
                                    1

                            Previous ->
                                if model.current_turn == 0 then
                                    0

                                else
                                    -1
                          )
            }



-- VIEW


view : Maybe Model -> Html Msg
view maybeModel =
    div
        [ style "width" "80%" ]
        [ viewGameBar maybeModel
        , Grid.view <|
            Maybe.andThen
                (\model -> Array.get model.current_turn model.turns)
                maybeModel
        ]


viewGameBar : Maybe Model -> Html Msg
viewGameBar maybeModel =
    div [ class "game-bar" ] <|
        case maybeModel of
            Just model ->
                [ viewArrows model ]

            Nothing ->
                []


viewArrows : Model -> Html Msg
viewArrows model =
    div [ class "d-flex justify-content-center align-items-center" ]
        [ button
            [ onClick (ChangeTurn Previous)
            , disabled (model.current_turn == 0)
            , class "arrow-button"
            ]
            [ text "←" ]
        , div [ style "width" "5rem", class "text-center" ] [ text <| "Turn " ++ String.fromInt (model.current_turn + 1) ]
        , button
            [ onClick (ChangeTurn Next)
            , disabled (model.current_turn == Array.length model.turns - 1)
            , class "arrow-button"
            ]
            [ text "→" ]
        ]
