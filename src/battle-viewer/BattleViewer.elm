module BattleViewer exposing (Model, Msg(..), init, update, view)

import Api
import Array exposing (Array)
import Data
import Dict
import GridViewer
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import OpponentSelect


to_perc : Float -> String
to_perc float =
    String.fromFloat float ++ "%"



-- MODEL


type alias Model =
    { apiContext : Api.Context
    , winner : Maybe (Maybe Data.Team)
    , renderState : RenderState
    , opponentSelectState : OpponentSelect.Model
    , viewingOpponentSelect : Bool
    , assetsPath : String
    }


type RenderState
    = Initializing Int
    | Render RenderStateVal
    | Error Data.OutcomeError
    | NoRender
    | InternalError


type alias RenderStateVal =
    { logs : List String
    , viewerState : GridViewer.Model
    , turnNum : Int
    }


init : Api.Context -> String -> ( Model, Cmd Msg )
init apiContext assetsPath =
    let
        ( model, cmd ) =
            OpponentSelect.init apiContext
    in
    ( Model apiContext Nothing NoRender model False assetsPath, cmd |> Cmd.map GotOpponentSelectMsg )



-- UPDATE


type Msg
    = GotOutput Data.OutcomeData
    | GotProgress Data.ProgressData
    | GotInternalError
    | Run Int
    | GotRenderMsg GridViewer.Msg
    | GotOpponentSelectMsg OpponentSelect.Msg
    | ToggleOpponentSelect


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ToggleOpponentSelect ->
            ( { model | viewingOpponentSelect = not model.viewingOpponentSelect }
              -- dirty fix for a problem where the very first `init` Cmd Http request simply does not go through
              -- in addition to attempting to retrieve robots then, also retrieve them when the user opens
              -- the robot selection menu
            , if not model.viewingOpponentSelect then
                Api.getUserRobots model.apiContext model.apiContext.user |> Api.makeRequest (OpponentSelect.GotUserRobots >> GotOpponentSelectMsg)

              else
                Cmd.none
            )

        GotOpponentSelectMsg selectMsg ->
            let
                ( selectModel, selectCmd ) =
                    OpponentSelect.update selectMsg model.opponentSelectState
            in
            ( { model
                | opponentSelectState = selectModel
                , viewingOpponentSelect =
                    case selectMsg of
                        OpponentSelect.SelectOpponent _ ->
                            False

                        _ ->
                            model.viewingOpponentSelect
              }
            , Cmd.map GotOpponentSelectMsg selectCmd
            )

        other ->
            ( case other of
                GotOutput output ->
                    let
                        maybeError =
                            Dict.get "Red" output.errors
                    in
                    { model
                        | renderState =
                            case maybeError of
                                Just error ->
                                    Error error

                                _ ->
                                    model.renderState
                        , winner = Just output.winner
                    }

                GotProgress progress ->
                    { model
                        | renderState =
                            let
                                turnLogs =
                                    Dict.get "Red" progress.logs
                                        |> Maybe.andThen
                                            (\logs ->
                                                if List.isEmpty logs then
                                                    Nothing

                                                else
                                                    Just logs
                                            )

                                addTurnHeading =
                                    \logs ->
                                        let
                                            headingStart =
                                                if progress.state.turn == 1 then
                                                    "Turn "

                                                else
                                                    "\nTurn "
                                        in
                                        (headingStart ++ String.fromInt progress.state.turn ++ "\n") :: logs

                                finalLogs =
                                    Maybe.withDefault [] (Maybe.map addTurnHeading turnLogs)
                            in
                            case model.renderState of
                                Render renderState ->
                                    Render
                                        { renderState
                                            | logs = List.append renderState.logs finalLogs
                                            , viewerState =
                                                GridViewer.update (GridViewer.GotTurn progress) renderState.viewerState
                                        }

                                Initializing turnNum ->
                                    Render
                                        { turnNum = turnNum
                                        , logs = finalLogs
                                        , viewerState = GridViewer.init progress turnNum
                                        }

                                other2 ->
                                    other2
                    }

                Run turnNum ->
                    { model | renderState = Initializing turnNum }

                GotRenderMsg renderMsg ->
                    case model.renderState of
                        Render state ->
                            { model | renderState = Render { state | viewerState = GridViewer.update renderMsg state.viewerState } }

                        _ ->
                            model

                GotInternalError ->
                    { model | renderState = InternalError }

                _ ->
                    model
            , Cmd.none
            )



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "_app-root" ]
        [ div [ class "_bar" ]
            [ p []
                [ text <|
                    "battle versus "
                        ++ (case model.opponentSelectState.opponent of
                                OpponentSelect.Robot ( robot, _ ) ->
                                    robot.name

                                OpponentSelect.Itself ->
                                    "itself"
                           )
                ]
            , button [ onClick ToggleOpponentSelect, class "_select-button" ]
                [ p [ class "mr-2" ] [ text "change opponent" ]
                , img
                    [ src <|
                        model.assetsPath
                            ++ (if model.viewingOpponentSelect then
                                    "/images/close-panel.svg"

                                else
                                    "/images/open-panel.svg"
                               )
                    ]
                    []
                ]
            ]
        , if model.viewingOpponentSelect then
            OpponentSelect.view model.opponentSelectState |> Html.map GotOpponentSelectMsg

          else
            div []
                [ div [ class "_battle-viewer-root" ]
                    [ viewBar model
                    , Html.map GotRenderMsg <|
                        case model.renderState of
                            Render state ->
                                GridViewer.view (Just state.viewerState)

                            _ ->
                                GridViewer.view Nothing
                    ]
                , viewLog model
                ]
        ]


viewLog : Model -> Html Msg
viewLog model =
    div [ class "_logs box" ]
        [ p [ class "header" ] [ text "Logs" ]
        , case model.renderState of
            Error error ->
                textarea
                    [ readonly True
                    , class "error"
                    ]
                    [ text <| Data.outcomeErrorToString error ]

            Render state ->
                if List.isEmpty state.logs then
                    p [ class "info" ] [ text "nothing here" ]

                else
                    textarea
                        [ readonly True
                        ]
                        [ text <| String.concat state.logs ]

            _ ->
                p [ class "info" ] [ text "nothing here" ]
        ]


viewBar : Model -> Html Msg
viewBar model =
    let
        viewButtons () =
            div [ class "_battle" ]
                [ p [] [ text "battle:" ]
                , div [ class "_buttons" ]
                    ([ 5, 20, 100 ]
                        |> List.map
                            (\turn_num ->
                                button
                                    [ onClick <| Run turn_num
                                    , class "button"
                                    ]
                                    [ text <| String.fromInt turn_num ++ " Turns" ]
                            )
                    )
                ]
    in
    div [ class "_run-bar" ]
        [ div [ class "_progress-outline" ] []
        , div [ class "_battle-section" ]
            [ case model.renderState of
                Render render ->
                    let
                        totalTurns =
                            Array.length render.viewerState.turns
                    in
                    if totalTurns /= render.turnNum then
                        div [ class "_progress", style "width" <| to_perc (toFloat totalTurns / toFloat render.turnNum * 100) ] []

                    else
                        viewButtons ()

                Initializing _ ->
                    p [ class "_text" ] [ text "Initializing..." ]

                _ ->
                    viewButtons ()
            ]
        , div [ class "_winner-section" ]
            [ p [ class "mr-2" ] [ text "winner: " ]
            , case model.winner of
                Just winner ->
                    case winner of
                        Just team ->
                            p [ class <| "team-" ++ team ] [ text team ]

                        Nothing ->
                            p [] [ text "Draw" ]

                Nothing ->
                    p [] [ text "?" ]
            ]
        ]
