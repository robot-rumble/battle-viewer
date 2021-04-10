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
    { isOurTeam : Bool, health : Int, obj : Data.Obj, action : Data.ActionResult, debugInspectTable : Maybe Data.DebugInspectTable }


type alias Model =
    { turns : Array Data.ProgressData
    , turnNum : Int
    , currentTurn : Int
    , selectedUnit : Maybe Unit
    , team : Maybe Data.Team
    , logs : List String
    , error : Maybe Error
    , userOwnsOpponent : Bool
    }


type Error
    = InternalError
    | GameError ErrorDetails


type alias ErrorDetails =
    { error : Data.OutcomeError
    , isOurTeam : Bool
    }


init : Int -> Maybe Data.Team -> Bool -> Bool -> Model
init turnNum maybeTeam userOwnsOpponent hasErrored =
    -- hasErrored is for setting the state to display an internal message
    -- in the case that such a message has been reported 'from the outside'
    -- through a port. This happens in the case of worker errors.
    let
        error =
            if hasErrored then
                Just InternalError

            else
                Nothing
    in
    Model Array.empty turnNum 0 Nothing maybeTeam [] error userOwnsOpponent



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


selectUnit : Data.Id -> Maybe Data.Team -> Data.ProgressData -> Maybe Unit
selectUnit unitId maybeTeam turn =
    case ( Dict.get unitId turn.state.objs, Dict.get unitId turn.robotActions, Dict.get unitId turn.debugInspectTables ) of
        ( Just (( _, details ) as obj), Just action, debugInspectTable ) ->
            case details of
                Data.UnitDetails unit ->
                    let
                        isOurTeam =
                            case maybeTeam of
                                Just team ->
                                    unit.team == team

                                Nothing ->
                                    False
                    in
                    Just <| Unit isOurTeam unit.health obj action debugInspectTable

                _ ->
                    Nothing

        _ ->
            Nothing


unitWithRuntimeError : Maybe Data.Team -> Data.ProgressData -> Maybe Unit
unitWithRuntimeError maybeTeam turn =
    turn.robotActions
        |> Dict.toList
        |> List.filterMap
            (\( id, action ) ->
                case action of
                    Ok _ ->
                        Nothing

                    Err _ ->
                        selectUnit id maybeTeam turn
                            |> Maybe.andThen
                                (\unit ->
                                    if unit.isOurTeam then
                                        Just unit

                                    else
                                        Nothing
                                )
            )
        |> List.head


changeTurn : Model -> Int -> Model
changeTurn model newTurn =
    { model
        | currentTurn = newTurn
        , selectedUnit =
            Array.get newTurn model.turns
                |> Maybe.andThen
                    (\turn ->
                        case model.selectedUnit of
                            Just unit ->
                                selectUnit (first unit.obj).id model.team turn

                            Nothing ->
                                unitWithRuntimeError model.team turn
                    )
    }


update : Msg -> Model -> Model
update msg model =
    case msg of
        GotTurn turn ->
            { model
                | turns = Array.push turn model.turns
                , logs = List.append model.logs (processLogs model.team turn)
                , selectedUnit =
                    case model.selectedUnit of
                        Just unit ->
                            Just unit

                        Nothing ->
                            -- if any units have a runtime error on the first turn only, select that unit
                            if Array.isEmpty model.turns then
                                unitWithRuntimeError model.team turn

                            else
                                Nothing
            }

        GotErrors errors ->
            { model
                | error =
                    case model.team |> Maybe.andThen (\team -> Dict.get team errors) of
                        Just error ->
                            Just <| GameError { error = error, isOurTeam = True }

                        Nothing ->
                            errors |> Dict.values |> List.head |> Maybe.map (\error -> GameError { error = error, isOurTeam = False })
            }

        ChangeTurn dir ->
            let
                newTurn =
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
            in
            changeTurn model newTurn

        SliderChange change ->
            changeTurn model <| Maybe.withDefault 0 (String.toInt change)

        GotGridMsg gridMsg ->
            case gridMsg of
                Grid.UnitSelected unitId ->
                    { model
                        | selectedUnit =
                            Array.get model.currentTurn model.turns
                                |> Maybe.andThen
                                    (\turn ->
                                        selectUnit unitId model.team turn
                                    )
                    }

        ResetSelectedUnit ->
            { model | selectedUnit = Nothing }

        NoOp ->
            model



-- VIEW


view : Maybe Model -> Html Msg
view maybeModel =
    let
        logBoxShown =
            case maybeModel of
                Just model ->
                    model.team /= Nothing

                Nothing ->
                    True
    in
    div [ class "_grid-viewer-root" ] <|
        [ viewMain maybeModel ]
            ++ (if logBoxShown then
                    [ viewLogs maybeModel ]

                else
                    []
               )


viewMain : Maybe Model -> Html Msg
viewMain maybeModel =
    div
        [ class "_grid-viewer", onClick ResetSelectedUnit ]
        [ div
            [ class "_grid-viewer-main"

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
        , div
            [ stopPropagationOn "click" (Decode.succeed ( NoOp, True ))
            , class "_inspector"
            ]
            [ viewRobotInspector
                (maybeModel |> Maybe.andThen (\model -> model.selectedUnit))
                (maybeModel |> Maybe.andThen (\model -> model.team))
                (case maybeModel of
                    Just model ->
                        model.userOwnsOpponent

                    Nothing ->
                        False
                )
            ]
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
                [ p [ class "_turn-indicator" ] [ text "Turn 0" ] ]


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
            , disabled (Array.length model.turns == 0 || model.currentTurn == Array.length model.turns - 1)
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
        , disabled <| Array.length model.turns == 0
        ]
        []


viewErrorDetails : Data.ErrorDetails -> Html Msg
viewErrorDetails errorDetails =
    div []
        [ p [ class "error" ] [ text errorDetails.summary ]
        , case ( errorDetails.details, errorDetails.loc ) of
            ( Just details, _ ) ->
                p [ class "error", style "white-space" "pre" ] [ text details ]

            ( Nothing, Just loc ) ->
                p [ class "error mt-2" ] [ text <| "Line: " ++ String.fromInt (first loc.start) ]

            _ ->
                div [] []
        ]


maxHealth =
    5


viewRobotInspector : Maybe Unit -> Maybe Data.Team -> Bool -> Html Msg
viewRobotInspector maybeUnit maybeTeam userOwnsOpponent =
    div [ class "box" ]
        [ p [ class "title" ] <|
            [ text "Robot Data" ]
                ++ (case maybeUnit of
                        Just unit ->
                            if not unit.isOurTeam && maybeTeam /= Nothing then
                                [ span [ class "text-red" ] [ text " (opponent)" ] ]

                            else
                                []

                        Nothing ->
                            []
                   )
        , case maybeUnit of
            Just unit ->
                div []
                    [ div []
                        [ div []
                            [ p [] [ text <| "Id: " ++ (first unit.obj).id ]
                            , p [] [ text <| "Coords: " ++ Data.coordsToString (first unit.obj).coords ]
                            , p [] [ text <| "Health: " ++ String.fromInt unit.health ++ " / " ++ String.fromInt maxHealth ]
                            ]
                        , case unit.action of
                            Ok (Just action) ->
                                p [] [ text <| "Next action: " ++ Data.actionToString action ]

                            Ok Nothing ->
                                p [] [ text <| "Next action: pass" ]

                            Err robotError ->
                                div [ class "mt-3" ]
                                    [ if unit.isOurTeam || userOwnsOpponent then
                                        case robotError of
                                            Data.RuntimeError errorDetails ->
                                                viewErrorDetails errorDetails

                                            Data.InvalidAction message ->
                                                p [ class "error" ] [ text message ]

                                      else
                                        p [ class "error" ] [ text "Errored" ]
                                    ]
                        ]
                    ]

            Nothing ->
                div [] [ p [ class "info" ] [ text "No unit selected" ] ]
        , case maybeUnit of
            Just unit ->
                if unit.isOurTeam || userOwnsOpponent then
                    div [ class "_table-wrapper" ]
                        [ let
                            debugPairs =
                                case unit.debugInspectTable of
                                    Just debugInspectTable ->
                                        Dict.toList debugInspectTable

                                    Nothing ->
                                        []
                          in
                          if List.isEmpty debugPairs then
                            p [ class "info mt-1" ] [ text "no data inspected. ", a [ href "https://rr-docs.readthedocs.io/en/latest/debugging.html", target "_blank" ] [ text "learn more" ] ]

                          else
                            div [ class "_table mt-1" ] <|
                                List.map
                                    (\( key, val ) ->
                                        p [] [ text <| key ++ ": " ++ val ]
                                    )
                                    debugPairs
                        ]

                else
                    div [ style "padding" "0" ] []

            Nothing ->
                div [ style "padding" "0" ] []
        ]


internalError : Html Msg
internalError =
    p [ class "error" ] [ text "Internal error! Something broke. This is automatically recorded, so just please tight while we figure this out. Feel free to reach out to antonoutkine At gmail Dot com with any questions." ]


viewLogs : Maybe Model -> Html Msg
viewLogs maybeModel =
    div [ class "_logs box mt-4" ]
        [ p [ class "title" ] [ text "Logs" ]
        , case maybeModel of
            Just model ->
                case model.error of
                    Just error ->
                        case error of
                            InternalError ->
                                div []
                                    [ internalError ]

                            GameError errorDetails ->
                                div []
                                    [ if not errorDetails.isOurTeam then
                                        internalError

                                      else
                                        div [] []
                                    , case errorDetails.error of
                                        Data.InitError initErrorDetails ->
                                            div [ style "white-space" "pre", class "error-wrapper mt-2" ]
                                                [ if model.userOwnsOpponent then
                                                    viewErrorDetails initErrorDetails

                                                  else
                                                    div [] []
                                                ]

                                        _ ->
                                            p [ class "error" ] [ text "Internal error! Something broke. This is automatically recorded, so just please tight while we figure this out. Feel free to reach out to antonoutkine At gmail Dot com with any questions." ]
                                    ]

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
