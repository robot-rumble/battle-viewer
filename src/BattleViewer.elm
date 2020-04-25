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
    , winner : Maybe (Maybe Data.Team)
    , renderState : RenderState
    }


type RenderState
    = Initializing
    | Render RenderStateVal
    | Error Data.OutcomeError
    | NoRender
    | InternalError


type alias RenderStateVal =
    { logs : List String
    , viewerState : GridViewer.Model
    }


init : Int -> Model
init totalTurns =
    Model totalTurns Nothing NoRender



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
                                { logs = List.append renderState.logs finalLogs
                                , viewerState =
                                    GridViewer.update (GridViewer.GotTurn progress) renderState.viewerState
                                }

                        _ ->
                            Render
                                { logs = finalLogs
                                , viewerState = GridViewer.init progress model.totalTurns
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
        , div [ class "_battle-viewer-root" ]
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
        viewButtons =
            div [ class "_battle" ]
                [ p [] [ text "battle:" ]
                , div [ class "_buttons" ]
                    ([ 5, 20, 100 ]
                        |> List.map
                            (\turn_count ->
                                button
                                    [ onClick Run
                                    , class "button"
                                    ]
                                    [ text <| String.fromInt turn_count ++ " Turns" ]
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
                    if totalTurns /= model.totalTurns then
                        div [ class "_progress", style "width" <| to_perc (toFloat totalTurns / toFloat model.totalTurns * 100) ] []

                    else
                        viewButtons

                Initializing ->
                    p [ class "_text" ] [ text "Initializing..." ]

                _ ->
                    viewButtons
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
