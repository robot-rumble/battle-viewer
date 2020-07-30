module GridViewer exposing (Model, Msg(..), init, update, view)

import Array exposing (Array)
import Data
import Dict
import Grid
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode
import Tuple exposing (..)



-- MODEL


type alias Unit =
    { isOurTeam : Bool, obj : Data.Obj, action : Data.ActionResult, debugTable : Maybe Data.DebugTable }


type alias Model =
    { turns : Array Data.ProgressData
    , turnNum : Int
    , currentTurn : Int
    , selectedUnit : Maybe Unit
    , team : Maybe Data.Team
    , logs : List String
    , error : Maybe Data.OutcomeError
    }


init : Int -> Maybe Data.Team -> Model
init turnNum maybeTeam =
    Model Array.empty turnNum 0 Nothing maybeTeam [] Nothing



-- UPDATE


type Msg
    = ChangeTurn Direction
    | GotTurn Data.ProgressData
    | GotErrors Data.OutcomeErrors
    | SliderChange String
    | GotGridMsg Grid.Msg
    | ResetSelectedUnit
    | NoOp


type Direction
    = Next
    | Previous


processLogs : Maybe Data.Team -> Data.ProgressData -> List String
processLogs maybeTeam turn =
    let
        turnLogs =
            maybeTeam
                |> Maybe.andThen
                    (\team ->
                        Dict.get team turn.logs
                            |> Maybe.andThen
                                (\logs ->
                                    if List.isEmpty logs then
                                        Nothing

                                    else
                                        Just logs
                                )
                    )

        addTurnHeading =
            \logs ->
                let
                    headingStart =
                        if turn.state.turn == 1 then
                            "Turn "

                        else
                            "\nTurn "
                in
                (headingStart ++ String.fromInt turn.state.turn ++ "\n") :: logs
    in
    Maybe.withDefault [] (Maybe.map addTurnHeading turnLogs)


unitWithRuntimeError : Maybe Data.Team -> Data.ProgressData -> Maybe Unit
unitWithRuntimeError maybeTeam turn =
    turn.robotActions
        |> Dict.toList
        |> List.filter
            (\( id, action ) ->
                case action of
                    Ok _ ->
                        False

                    Err _ ->
                        True
            )
        |> List.filterMap
            (\( id, action ) ->
                case ( Dict.get id turn.state.objs, Dict.get id turn.debugTables ) of
                    ( Just (( basic, details ) as obj), debugTable ) ->
                        case details of
                            Data.UnitDetails unit ->
                                maybeTeam
                                    |> Maybe.andThen
                                        (\team ->
                                            if unit.team == team then
                                                Just <| Unit True obj action debugTable

                                            else
                                                Nothing
                                        )

                            Data.TerrainDetails _ ->
                                Nothing

                    _ ->
                        Nothing
            )
        |> List.head


update : Msg -> Model -> Model
update msg model =
    case msg of
        GotTurn turn ->
            let
                selectedUnit =
                    -- if any units have a runtime error on the first turn only, select that unit
                    if Array.isEmpty model.turns then
                        unitWithRuntimeError model.team turn

                    else
                        Nothing

                logs =
                    List.append model.logs (processLogs model.team turn)
            in
            { model | turns = Array.push turn model.turns, logs = logs, selectedUnit = selectedUnit }

        GotErrors errors ->
            let
                maybeError =
                    model.team |> Maybe.andThen (\team -> Dict.get team errors)
            in
            { model | error = maybeError }

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
                    { model
                        | selectedUnit =
                            case Array.get model.currentTurn model.turns of
                                Just data ->
                                    case ( Dict.get unitId data.state.objs, Dict.get unitId data.robotActions, Dict.get unitId data.debugTables ) of
                                        ( Just (( basic, details ) as obj), Just action, debugTable ) ->
                                            case details of
                                                Data.UnitDetails unit ->
                                                    let
                                                        isOurTeam =
                                                            case model.team of
                                                                Just team ->
                                                                    unit.team == team

                                                                Nothing ->
                                                                    False
                                                    in
                                                    Just <| Unit isOurTeam obj action debugTable

                                                _ ->
                                                    Nothing

                                        _ ->
                                            Nothing

                                Nothing ->
                                    Nothing
                    }

        ResetSelectedUnit ->
            { model | selectedUnit = Nothing }

        NoOp ->
            model



-- VIEW


view : Maybe Model -> Html Msg
view maybeModel =
    div [ class "_grid-viewer-root" ] [ viewMain maybeModel, viewLogs maybeModel ]


viewMain : Maybe Model -> Html Msg
viewMain maybeModel =
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
            , Grid.view
                (maybeModel
                    |> Maybe.andThen
                        (\model ->
                            Array.get model.currentTurn model.turns
                                |> Maybe.map
                                    (\state ->
                                        ( state, model.selectedUnit |> Maybe.map (\unit -> (first unit.obj).id), model.team )
                                    )
                        )
                )
                |> Html.map GotGridMsg
            ]
        , case selectedUnit of
            Just ( model, unit ) ->
                div
                    [ stopPropagationOn "click" (Decode.succeed ( NoOp, True ))
                    , class "_inspector"
                    ]
                    [ viewRobotInspector unit
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


viewRobotInspector : Unit -> Html Msg
viewRobotInspector unit =
    div [ class "box" ]
        [ p [ class "title" ] [ text "Robot Data" ]
        , div []
            [ div [ class "mb-3" ]
                [ div []
                    [ p [] [ text <| "Id: " ++ (first unit.obj).id ]
                    , p [] [ text <| "Coords: " ++ Data.coordsToString (first unit.obj).coords ]
                    ]
                , case unit.action of
                    Ok action ->
                        p [] [ text <| "Action: " ++ Data.actionToString action ]

                    Err error ->
                        if unit.isOurTeam then
                            p [ class "error" ] [ text <| "Error: " ++ Data.robotErrorToString error ]

                        else
                            p [ class "error" ] [ text "Errored" ]
                ]
            , if unit.isOurTeam then
                let
                    debugPairs =
                        case unit.debugTable of
                            Just debugTable ->
                                Dict.toList debugTable

                            Nothing ->
                                []
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

              else
                div [] []
            ]
        ]


viewLogs : Maybe Model -> Html Msg
viewLogs maybeModel =
    div [ class "_logs box mt-4" ]
        [ p [ class "title" ] [ text "Logs" ]
        , case maybeModel of
            Just model ->
                case model.error of
                    Just error ->
                        textarea
                            [ readonly True
                            , class "error"
                            ]
                            [ text <| Data.outcomeErrorToString error ]

                    Nothing ->
                        if List.isEmpty model.logs then
                            p [ class "info" ] [ text "nothing here" ]

                        else
                            textarea
                                [ readonly True
                                ]
                                [ text <| String.concat model.logs ]

            Nothing ->
                p [ class "info" ] [ text "nothing here" ]
        ]
