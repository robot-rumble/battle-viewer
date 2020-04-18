module BattleViewerMain exposing (Model, Msg(..), RenderState(..), init, update, view)

import Array exposing (Array)
import BattleViewer
import Data
import Dict
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)


to_perc : Float -> String
to_perc float =
    String.fromFloat float ++ "%"



-- MODEL


type alias Model =
    { totalTurns : Int
    , renderState : RenderState
    }


type RenderState
    = Initializing
    | Render RenderStateVal
    | Error Data.E
    | NoRender
    | InternalError


type alias RenderStateVal =
    { logs : List String
    , viewerState : BattleViewer.Model
    }


init : Int -> Model
init totalTurns =
    Model totalTurns NoRender



-- UPDATE


type Msg
    = GotOutput Data.OutcomeData
    | GotProgress Data.ProgressData
    | GotInternalError
    | Run
    | GotRenderMsg BattleViewer.Msg


update : Msg -> Model -> Model
update msg model =
    case msg of
        GotOutput output ->
            let
                maybeError =
                    Dict.get "Red" output.errors
            in
            case maybeError of
                Just error ->
                    { model | renderState = Error error }

                _ ->
                    model

        GotProgress progress ->
            { model
                | renderState =
                    let
                        logs =
                            Maybe.withDefault [] (Dict.get "Red" progress.logs)

                        logsWithMarker =
                            let
                                turnStringStart =
                                    if progress.state.turn == 1 then
                                        "Turn "

                                    else
                                        "\nTurn "
                            in
                            (turnStringStart ++ String.fromInt progress.state.turn) :: logs
                    in
                    case model.renderState of
                        Render renderState ->
                            Render
                                { logs = List.append renderState.logs logsWithMarker
                                , viewerState =
                                    BattleViewer.update (BattleViewer.GotTurn progress.state) renderState.viewerState
                                }

                        _ ->
                            Render
                                { logs = logsWithMarker
                                , viewerState = BattleViewer.init progress.state model.totalTurns
                                }
            }

        Run ->
            { model | renderState = Initializing }

        GotRenderMsg renderMsg ->
            case model.renderState of
                Render state ->
                    { model | renderState = Render { state | viewerState = BattleViewer.update renderMsg state.viewerState } }

                _ ->
                    model

        GotInternalError ->
            { model | renderState = InternalError }



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "_app-root" ]
        [ div [ class "_battle-viewer-root d-flex flex-column align-items-center justify-content-center" ]
            [ viewButton model
            , Html.map GotRenderMsg <|
                case model.renderState of
                    Render state ->
                        BattleViewer.view (Just state.viewerState)

                    _ ->
                        BattleViewer.view Nothing
            ]
        , div [ class "_logs" ] [ viewLog model ]
        ]


viewLog : Model -> Html Msg
viewLog model =
    div [ class "box" ]
        [ p [] [ text "Logs" ]
        , textarea
            [ readonly True
            , class <|
                case model.renderState of
                    Error _ ->
                        "error"

                    _ ->
                        ""
            ]
            [ text <|
                case model.renderState of
                    Error error ->
                        error

                    Render state ->
                        String.concat state.logs

                    _ ->
                        ""
            ]
        ]


isLoading : Model -> Bool
isLoading model =
    case model.renderState of
        Render render ->
            Array.length render.viewerState.turns /= model.totalTurns

        Initializing ->
            True

        _ ->
            False


viewButton : Model -> Html Msg
viewButton model =
    let
        loading =
            isLoading model

        loadingBarPerc =
            if isLoading model then
                case model.renderState of
                    Render render ->
                        let
                            totalTurns =
                                Array.length render.viewerState.turns
                        in
                        Just (toFloat totalTurns / toFloat model.totalTurns * 100)

                    _ ->
                        Just 0

            else
                Nothing
    in
    div [ class "_run-bar mb-5" ]
        [ div [ class "_progress-outline" ] []
        , case loadingBarPerc of
            Just perc ->
                div [ class "_progress", style "width" <| to_perc perc ] []

            Nothing ->
                div [] []
        , button
            [ onClick Run
            , class "button"

            -- hide button through CSS to preserve bar height
            , style "visibility" <|
                if loading then
                    "hidden"

                else
                    "visible"
            ]
            [ text "battle!" ]
        , case model.renderState of
            Initializing ->
                p [ class "_text" ] [ text "Initializing..." ]

            _ ->
                div [] []
        ]
