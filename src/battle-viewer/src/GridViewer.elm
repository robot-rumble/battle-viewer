module GridViewer exposing (Model, Msg(..), init, update, view)

import Array exposing (Array)
import Data
import Dict
import Grid
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Tuple



-- MODEL


type alias Model =
    { turns : Array ( Data.TurnState, Data.RobotOutputs )
    , totalTurns : Int
    , currentTurn : Int
    , selectedUnit : Maybe Data.Id
    }


init : ( Data.TurnState, Data.RobotOutputs ) -> Int -> Model
init firstTurn totalTurns =
    Model (Array.fromList [ firstTurn ]) totalTurns 0 Nothing



-- UPDATE


type Msg
    = ChangeTurn Direction
    | GotTurn ( Data.TurnState, Data.RobotOutputs )
    | SliderChange String
    | GotGridMsg Grid.Msg


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
                | currentTurn =
                    model.currentTurn
                        + (case dir of
                            Next ->
                                if model.currentTurn == Array.length model.turns - 1 then
                                    0

                                else
                                    1

                            Previous ->
                                if model.currentTurn == 0 then
                                    0

                                else
                                    -1
                          )
            }

        SliderChange change ->
            { model | currentTurn = Maybe.withDefault 0 (String.toInt change) }

        GotGridMsg gridMsg ->
            case gridMsg of
                Grid.UnitSelected unitId ->
                    { model | selectedUnit = Just unitId }



-- VIEW


view : Maybe Model -> Html Msg
view maybeModel =
    div
        [ style "width" "80%" ]
        [ div [ class "mb-3" ]
            [ viewGameBar maybeModel
            , Html.map GotGridMsg
                (Grid.view <|
                    Maybe.andThen
                        (\model -> Maybe.map (\state -> ( Tuple.first state, model.selectedUnit )) <| Array.get model.currentTurn model.turns)
                        maybeModel
                )
            ]
        , viewRobotInspector maybeModel
        ]


viewGameBar : Maybe Model -> Html Msg
viewGameBar maybeModel =
    div [ class "_grid-viewer-controls d-flex justify-content-between align-items-center" ] <|
        case maybeModel of
            Just model ->
                [ p [ style "flex-basis" "30%" ] [ text <| "Turn " ++ String.fromInt (model.currentTurn + 1) ]
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
            , disabled (model.currentTurn == 0)
            , class "arrow-button"
            ]
            [ text "←" ]
        , button
            [ onClick (ChangeTurn Next)
            , disabled (model.currentTurn == Array.length model.turns - 1)
            , class "arrow-button"
            ]
            [ text "→" ]
        ]


viewSlider : Model -> Html Msg
viewSlider model =
    input
        [ type_ "range"
        , Html.Attributes.min "1"
        , Html.Attributes.max <| String.fromInt (model.totalTurns - 1)
        , value <| String.fromInt model.currentTurn
        , onInput SliderChange
        ]
        []


viewRobotInspector : Maybe Model -> Html Msg
viewRobotInspector maybeModel =
    div [ class "_inspector box" ]
        [ p [ class "header" ] [ text "Robot Data" ]
        , case
            Maybe.andThen
                (\model ->
                    case model.selectedUnit of
                        Just unitId ->
                            Just ( model, unitId )

                        Nothing ->
                            Nothing
                )
                maybeModel
          of
            Just ( model, unitId ) ->
                case Array.get model.currentTurn model.turns of
                    Just ( _, robotOutputs ) ->
                        div []
                            [ case Dict.get unitId robotOutputs of
                                Just robotOutput ->
                                    let
                                        debugPairs =
                                            Dict.toList robotOutput.debugTable
                                    in
                                    if List.isEmpty debugPairs then
                                        -- TODO link for robot debugging information
                                        p [ class "info" ] [ text "no data added. ", a [ href "" ] [ text "learn more" ] ]

                                    else
                                        div [ class "_table" ] <|
                                            List.map
                                                (\( key, val ) ->
                                                    p [] [ text <| key ++ ": " ++ val ]
                                                )
                                                debugPairs

                                Nothing ->
                                    p [] []
                            ]

                    Nothing ->
                        div [] []

            Nothing ->
                p [ class "info" ] [ text "nothing here" ]
        ]
