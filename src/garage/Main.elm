port module Main exposing (..)

import Api exposing (unwrapRobotId)
import BattleViewer
import Browser
import Data
import Html exposing (..)
import Html.Attributes exposing (..)
import Json.Decode as Decode
import Json.Encode as Encode
import OpponentSelect



-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { renderState : BattleViewer.Model
    , error : Bool
    }


type alias Flags =
    { team : Maybe Data.Team
    , apiContext : Api.ContextFlag
    , unsupported : Bool
    , tutorial : Bool
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        apiContext =
            Api.contextFlagtoContext flags.apiContext

        ( newModel, newCmd ) =
            BattleViewer.init True flags.team flags.unsupported flags.tutorial (OpponentSelect.Flags apiContext False)
    in
    ( Model newModel False, Cmd.map GotRenderMsg newCmd )



-- MSG


type Msg
    = GotOutput Decode.Value
    | GotProgress Decode.Value
    | GotRenderMsg BattleViewer.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotRenderMsg renderMsg ->
            let
                ( renderModel, renderCmd ) =
                    BattleViewer.update renderMsg model.renderState

                ( newModel, newCmd ) =
                    case renderMsg of
                        BattleViewer.Run turnNum ->
                            let
                                encodeEvalInfo ( code, lang ) =
                                    Encode.object
                                        [ ( "code", Encode.string code )
                                        , ( "lang", Encode.string lang )
                                        ]

                                maybeEvalInfoAndSettings =
                                    OpponentSelect.evalInfo model.renderState.opponentSelectState ( "", "" )

                                id =
                                    case model.renderState.opponentSelectState.opponent of
                                        OpponentSelect.Robot robotDetails ->
                                            robotDetails.robot.basic.id

                                        OpponentSelect.Itself ->
                                            Api.RobotId 0
                            in
                            case maybeEvalInfoAndSettings of
                                Just ( opponentEvalInfo, maybeSettings ) ->
                                    ( { model | renderState = renderModel }
                                    , startEval <|
                                        Encode.object
                                            [ ( "opponentEvalInfo", encodeEvalInfo opponentEvalInfo )
                                            , ( "turns", Encode.int turnNum )
                                            , ( "settings", Data.encodeNull Data.simulationSettingsEncoder maybeSettings )
                                            , ( "id", Encode.int <| unwrapRobotId id )
                                            ]
                                    )

                                Nothing ->
                                    ( { model | renderState = renderModel }, Cmd.none )

                        _ ->
                            ( { model | renderState = renderModel }, Cmd.none )
            in
            let
                reportApiErrorCmd =
                    case renderModel.apiError of
                        Just error ->
                            reportApiError error

                        Nothing ->
                            Cmd.none
            in
            ( newModel, Cmd.batch [ renderCmd |> Cmd.map GotRenderMsg, newCmd, reportApiErrorCmd ] )

        GotOutput output ->
            model |> handleDecodeData (Data.decodeOutcomeData output) BattleViewer.GotOutput

        GotProgress progress ->
            model |> handleDecodeData (Data.decodeProgressData progress) BattleViewer.GotProgress


handleDecodeData decodedData msg model =
    case decodedData of
        Ok data ->
            let
                ( newModel, newCmd ) =
                    BattleViewer.update (msg data) model.renderState
            in
            ( { model | renderState = newModel }, newCmd |> Cmd.map GotRenderMsg )

        Err error ->
            ( { model | error = True }, reportDecodeError <| Decode.errorToString error )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ getOutput GotOutput
        , getProgress GotProgress
        , getInternalError (always <| GotRenderMsg BattleViewer.GotInternalError)
        , getTooLong (always <| GotRenderMsg BattleViewer.GotTooLong)
        , finishedDownloading (always <| GotRenderMsg BattleViewer.FinishedDownloadingRunner)
        , finishedLoading (always <| GotRenderMsg BattleViewer.FinishedLoadingRunner)
        ]


port getOutput : (Decode.Value -> msg) -> Sub msg


port getProgress : (Decode.Value -> msg) -> Sub msg


port startEval : Encode.Value -> Cmd msg


port reportDecodeError : String -> Cmd msg


port reportApiError : String -> Cmd msg


port getInternalError : (() -> msg) -> Sub msg


port finishedDownloading : (() -> msg) -> Sub msg


port finishedLoading : (() -> msg) -> Sub msg


port getTooLong : (() -> msg) -> Sub msg



-- VIEW


view : Model -> Html Msg
view model =
    div [] <|
        (if model.error then
            [ div [ class "_error error mt-4 mb-4" ] [ text "Internal error! Something broke. This is automatically recorded, so please hang tight while we figure this out." ] ]

         else
            []
        )
            ++ [ BattleViewer.view model.renderState |> Html.map GotRenderMsg ]
