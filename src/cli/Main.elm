port module Main exposing (getOutput, getProgress, main, startEval)

import Api
import BattleViewer
import Browser
import Data
import Html exposing (..)
import Html.Attributes exposing (..)
import Json.Decode as Decode
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
    { code : String
    , team : Maybe Data.Team
    , apiContext : Api.ContextFlag
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        apiContext =
            Api.contextFlagtoContext flags.apiContext

        ( newModel, newCmd ) =
            BattleViewer.init apiContext False flags.team False
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

                newCmd =
                    case renderMsg of
                        BattleViewer.Run turns ->
                            let
                                id =
                                    case model.renderState.opponentSelectState.opponent of
                                        OpponentSelect.Robot robotDetails ->
                                            robotDetails.robot.basic.id

                                        OpponentSelect.Itself ->
                                            Api.RobotId 0
                            in
                            startEval { id = Api.unwrapRobotId id, turns = turns }

                        _ ->
                            Cmd.none
            in
            ( { model | renderState = renderModel }, Cmd.batch [ renderCmd |> Cmd.map GotRenderMsg, newCmd ] )

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


subscriptions _ =
    Sub.batch
        [ getProgress GotProgress
        , getOutput GotOutput
        ]


port getOutput : (Decode.Value -> msg) -> Sub msg


port getProgress : (Decode.Value -> msg) -> Sub msg


port startEval : { id : Int, turns : Int } -> Cmd msg


port reportDecodeError : String -> Cmd msg



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
