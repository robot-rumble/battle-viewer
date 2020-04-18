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
    | SliderChange String


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

        SliderChange change ->
            { model | current_turn = Maybe.withDefault 0 (String.toInt change) }



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
    div [ class "_grid-viewer-controls d-flex justify-content-between align-items-center" ] <|
        case maybeModel of
            Just model ->
                [ p [ style "flex-basis" "30%" ] [ text <| "Turn " ++ String.fromInt (model.current_turn + 1) ]
                , div
                    [ class "d-flex justify-content-around align-items-center"
                    ]
                    [ viewArrows model
                    , viewSlider model
                    ]
                ]

            Nothing ->
                [ p [] [ text "Turn 0" ] ]


viewArrows : Model -> Html Msg
viewArrows model =
    div [ class "d-flex justify-content-center align-items-center" ]
        [ button
            [ onClick (ChangeTurn Previous)
            , disabled (model.current_turn == 0)
            , class "arrow-button"
            ]
            [ text "←" ]
        , button
            [ onClick (ChangeTurn Next)
            , disabled (model.current_turn == Array.length model.turns - 1)
            , class "arrow-button"
            ]
            [ text "→" ]
        ]


viewSlider : Model -> Html Msg
viewSlider model =
    input
        [ type_ "range"
        , Html.Attributes.min "1"
        , Html.Attributes.max <| String.fromInt (model.total_turns - 1)
        , value <| String.fromInt model.current_turn
        , onInput SliderChange
        ]
        []
