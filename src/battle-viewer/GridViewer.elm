module GridViewer exposing (Model, Msg(..), init, update, view)

import Array exposing (Array)
import Data
import Dict
import Grid
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode
import Tuple



-- MODEL


type alias Model =
    { turns : Array Data.ProgressData
    , turnNum : Int
    , currentTurn : Int
    , selectedUnit : Maybe Data.Id
    }


init : Data.ProgressData -> Int -> Model
init firstTurn turnNum =
    Model (Array.fromList [ firstTurn ]) turnNum 0 Nothing



-- UPDATE


type Msg
    = ChangeTurn Direction
    | GotTurn Data.ProgressData
    | SliderChange String
    | GotGridMsg Grid.Msg
    | ResetSelectedUnit
    | NoOp


type Direction
    = Next
    | Previous


update : Msg -> Model -> Model
update msg model =
    case msg of
        GotTurn turn ->
            { model
                | turns = Array.push turn model.turns
                , selectedUnit =
                    case model.selectedUnit of
                        Just unit ->
                            Just unit

                        Nothing ->
                            turn.robotOutputs
                                |> Dict.toList
                                |> List.filter
                                    (\( id, _ ) ->
                                        case turn.state.objs |> Dict.get id of
                                            Just ( basic, details ) ->
                                                case details of
                                                    Data.UnitDetails unit ->
                                                        unit.team == "Red"

                                                    Data.TerrainDetails _ ->
                                                        False

                                            Nothing ->
                                                False
                                    )
                                |> List.filterMap
                                    (\( id, output ) ->
                                        case output.action of
                                            Ok _ ->
                                                Nothing

                                            Err _ ->
                                                Just id
                                    )
                                |> List.head
            }

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

        ResetSelectedUnit ->
            { model | selectedUnit = Nothing }

        NoOp ->
            model



-- VIEW


view : Maybe Model -> Html Msg
view maybeModel =
    let
        selectedUnit =
            maybeModel
                |> Maybe.andThen
                    (\model ->
                        case model.selectedUnit of
                            Just unitId ->
                                Just ( model, unitId )

                            Nothing ->
                                Nothing
                    )
    in
    div
        [ class "_grid-viewer", onClick ResetSelectedUnit ]
        [ div
            [ class "_grid-viewer-main"
            , class <|
                case selectedUnit of
                    Nothing ->
                        "mx-auto"

                    Just _ ->
                        ""

            -- prevent clicking on grid from closing the inspector
            , stopPropagationOn "click" (Decode.succeed ( NoOp, True ))
            ]
            [ viewGameBar maybeModel
            , Html.map GotGridMsg
                (Grid.view
                    (maybeModel
                        |> Maybe.andThen
                            (\model ->
                                Array.get model.currentTurn model.turns
                                    |> Maybe.map (\state -> ( state, model.selectedUnit ))
                            )
                    )
                )
            ]
        , case selectedUnit of
            Just ( model, unitId ) ->
                div
                    [ stopPropagationOn "click" (Decode.succeed ( NoOp, True ))
                    , class "_inspector"
                    ]
                    [ viewRobotInspector model unitId
                    ]

            Nothing ->
                div [] []
        ]


viewGameBar : Maybe Model -> Html Msg
viewGameBar maybeModel =
    div [ class "_grid-viewer-controls" ] <|
        case maybeModel of
            Just model ->
                [ p [ class "_turn-indicator" ] [ text <| "Turn " ++ String.fromInt (model.currentTurn + 1) ]
                , viewArrows model
                , viewSlider model
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
        , Html.Attributes.min "0"
        , Html.Attributes.max <| String.fromInt (model.turnNum - 1)
        , value <| String.fromInt model.currentTurn
        , onInput SliderChange
        ]
        []


viewRobotInspector : Model -> Data.Id -> Html Msg
viewRobotInspector model unitId =
    div [ class "box" ]
        [ p [ class "header" ] [ text "Robot Data" ]
        , case Array.get model.currentTurn model.turns of
            Just data ->
                div []
                    [ case Dict.get unitId data.robotOutputs of
                        Just robotOutput ->
                            div []
                                [ div [ class "mb-3" ]
                                    [ case robotOutput.action of
                                        Ok action ->
                                            p [] [ text <| "Action: " ++ Data.actionToString action ]

                                        Err error ->
                                            p [ class "error" ] [ text <| "Error: " ++ Data.robotErrorToString error ]
                                    ]
                                , let
                                    debugPairs =
                                        Dict.toList robotOutput.debugTable
                                  in
                                  if List.isEmpty debugPairs then
                                    p [ class "info" ] [ text "no watch data. ", a [ href "https://rr-docs.readthedocs.io/en/latest/quickstart.html#debugging-your-robot", target "_blank" ] [ text "learn more" ] ]

                                  else
                                    div [ class "_table" ] <|
                                        List.map
                                            (\( key, val ) ->
                                                p [] [ text <| key ++ ": " ++ val ]
                                            )
                                            debugPairs
                                ]

                        Nothing ->
                            p [] []
                    ]

            Nothing ->
                div [] []
        ]
