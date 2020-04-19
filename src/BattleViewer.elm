module BattleViewer exposing (Model, Msg(..), init, update, view)

import Array exposing (Array)
import Data
import Dict
import GridViewer
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
    , viewerState : GridViewer.Model
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
    | GotRenderMsg GridViewer.Msg


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
                                { logs = List.append renderState.logs finalLogs
                                , viewerState =
                                    GridViewer.update (GridViewer.GotTurn ( progress.state, progress.robotOutputs )) renderState.viewerState
                                }

                        _ ->
                            Render
                                { logs = finalLogs
                                , viewerState = GridViewer.init ( progress.state, progress.robotOutputs ) model.totalTurns
                                }
            }

        Run ->
            { model | renderState = Initializing }

        GotRenderMsg renderMsg ->
            case model.renderState of
                Render state ->
                    { model | renderState = Render { state | viewerState = GridViewer.update renderMsg state.viewerState } }

                _ ->
                    model

        GotInternalError ->
            { model | renderState = InternalError }



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "_app-root" ]
        [ div [ class "_bar" ] [ p [] [ text "battle versus itself" ] ]
        , div [ class "_battle-viewer-root d-flex flex-column align-items-center justify-content-center" ]
            [ viewButton model
            , Html.map GotRenderMsg <|
                case model.renderState of
                    Render state ->
                        GridViewer.view (Just state.viewerState)

                    _ ->
                        GridViewer.view Nothing
            ]
        , viewLog model
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
                    [ text error ]

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
