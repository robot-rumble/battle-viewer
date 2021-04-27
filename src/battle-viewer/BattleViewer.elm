module BattleViewer exposing (Model, Msg(..), RenderState(..), init, update, view)

import Api
import Array exposing (Array)
import Data
import GridViewer
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import OpponentSelect


to_percent : Float -> String
to_percent float =
    String.fromFloat float ++ "%"



-- MODEL


type alias Model =
    { apiContext : Api.Context
    , apiError : Maybe String
    , winner : Maybe (Maybe Data.Team)
    , renderState : RenderState
    , opponentSelectState : OpponentSelect.Model
    , viewingOpponentSelect : Bool
    , team : Maybe Data.Team
    , takingTooLong : Bool
    , unsupported : Bool
    }


userOwnsOpponent : Model -> Bool
userOwnsOpponent model =
    OpponentSelect.userOwnsOpponent model.opponentSelectState model.apiContext


type RenderState
    = DownloadingRunner
    | LoadingRunner
    | NoRender
    | Initializing Int
    | Render RenderStateVal
    | InternalError GridViewer.Model


type alias RenderStateVal =
    ( Int, GridViewer.Model )


init : Api.Context -> Bool -> Maybe Data.Team -> Bool -> ( Model, Cmd Msg )
init apiContext isRunnerLoading team unsupported =
    let
        ( model, cmd ) =
            OpponentSelect.init apiContext

        renderState =
            if isRunnerLoading then
                DownloadingRunner

            else
                NoRender
    in
    ( Model apiContext Nothing Nothing renderState model False team False unsupported, cmd |> Cmd.map GotOpponentSelectMsg )



-- UPDATE


type Msg
    = FinishedDownloadingRunner
    | FinishedLoadingRunner
    | GotOutput Data.OutcomeData
    | GotProgress Data.ProgressData
    | GotInternalError
    | GotTooLong
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
                case model.apiContext.siteInfo of
                    Just info ->
                        Api.getUserRobots model.apiContext info.user |> Api.makeRequest (OpponentSelect.GotUserRobots >> GotOpponentSelectMsg)

                    Nothing ->
                        Cmd.none

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
                , apiError = selectModel.apiError

                -- reset any Internal error messages after new opponent is selected
                --, renderState = NoRender
                -- actually, we don't want to do this because worker errors seem to persist
              }
            , Cmd.map GotOpponentSelectMsg selectCmd
            )

        other ->
            ( case other of
                FinishedDownloadingRunner ->
                    { model | renderState = LoadingRunner }

                FinishedLoadingRunner ->
                    { model | renderState = NoRender }

                GotOutput output ->
                    { model
                        | renderState =
                            case model.renderState of
                                Render ( turn, viewerState ) ->
                                    Render ( turn, GridViewer.update (GridViewer.GotErrors output.errors) viewerState )

                                Initializing turn ->
                                    let
                                        viewerState =
                                            GridViewer.init turn model.team (userOwnsOpponent model) False
                                                |> GridViewer.update (GridViewer.GotErrors output.errors)
                                    in
                                    Render ( turn, viewerState )

                                other2 ->
                                    other2
                        , winner = Just output.winner
                    }

                GotProgress progress ->
                    { model
                        | renderState =
                            case model.renderState of
                                Render ( turn, viewerState ) ->
                                    Render ( turn, GridViewer.update (GridViewer.GotTurn progress) viewerState )

                                Initializing turn ->
                                    let
                                        viewerState =
                                            GridViewer.init turn model.team (userOwnsOpponent model) False
                                                |> GridViewer.update (GridViewer.GotTurn progress)
                                    in
                                    Render ( turn, viewerState )

                                other2 ->
                                    other2
                    }

                Run turnNum ->
                    { model | renderState = Initializing turnNum }

                GotRenderMsg renderMsg ->
                    case model.renderState of
                        Render ( turn, viewerState ) ->
                            { model | renderState = Render ( turn, GridViewer.update renderMsg viewerState ) }

                        _ ->
                            model

                GotInternalError ->
                    let
                        viewerState =
                            GridViewer.init 0 model.team (userOwnsOpponent model) True
                    in
                    { model | renderState = InternalError viewerState }

                GotTooLong ->
                    { model | takingTooLong = True }

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
                [ span [ class "text-blue" ]
                    [ text
                        (case model.apiContext.siteInfo of
                            Just info ->
                                info.robot

                            Nothing ->
                                "demo robot"
                        )
                    ]
                , text " versus "
                , span
                    [ class "text-red" ]
                    [ text <|
                        case model.opponentSelectState.opponent of
                            OpponentSelect.Robot robotDetails ->
                                robotDetails.robot.basic.name

                            OpponentSelect.Itself ->
                                "itself"
                    ]
                ]
            , button [ onClick ToggleOpponentSelect, class "_select-button d-flex align-items-end" ]
                [ p [ class "mr-2" ] [ text "change opponent" ]
                , div
                    [ class <|
                        if model.viewingOpponentSelect then
                            "_img-close-panel"

                        else
                            "_img-open-panel"
                    ]
                    []
                ]
            ]
        , if model.viewingOpponentSelect then
            OpponentSelect.view model.opponentSelectState |> Html.map GotOpponentSelectMsg

          else
            div [ class "_battle-viewer-root" ]
                [ viewBar model
                , Html.map GotRenderMsg <|
                    case model.renderState of
                        Render ( _, viewerState ) ->
                            GridViewer.view (Just viewerState) False

                        InternalError viewerState ->
                            GridViewer.view (Just viewerState) False

                        _ ->
                            GridViewer.view Nothing model.takingTooLong
                ]
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
                                    , id <| "run-" ++ String.fromInt turn_num ++ "-turns"
                                    ]
                                    [ text <| String.fromInt turn_num ++ " Turns" ]
                            )
                    )
                ]

        viewLoadingMessage message =
            div [ class "d-flex justify-content-center align-items-center" ]
                [ p [ class "_text mr-2" ] [ text message ]
                , div [ class "_img-spinner" ] []
                ]
    in
    div [ class "_run-bar" ]
        [ div [ class "_progress-outline" ] []
        , div [ class "_battle-section" ]
            [ if model.unsupported then
                p [ class "error" ] [ text "Unsupported browser type!" ]

              else
                case model.renderState of
                    Render ( turn, viewerState ) ->
                        let
                            totalTurns =
                                Array.length viewerState.turns
                        in
                        if totalTurns /= turn && viewerState.error == Nothing then
                            div [ class "_progress", style "width" <| to_percent (toFloat totalTurns / toFloat turn * 100) ] []

                        else
                            viewButtons ()

                    Initializing _ ->
                        p [ class "_text" ] [ text "Initializing..." ]

                    DownloadingRunner ->
                        viewLoadingMessage "Loading runner..."

                    LoadingRunner ->
                        viewLoadingMessage "Compiling runner..."

                    InternalError _ ->
                        p [ class "error" ] [ text "Internal error!" ]

                    NoRender ->
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
