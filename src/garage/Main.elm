port module Main exposing (..)

import Api
import BattleViewer
import Browser
import Data
import Dict
import Grid
import GridViewer
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import OpponentSelect
import Settings



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


type
    SaveAnimationPhase
    -- hacky way to get the disappearing animation to restart on every save
    -- by alternating between two different but equal animations
    = Initial
    | One
    | Two


type alias Model =
    { paths : Paths
    , apiContext : Api.Context
    , code : String
    , lang : String
    , battleViewerModel : BattleViewer.Model
    , saveAnimationPhase : SaveAnimationPhase
    , error : Maybe Data.Error
    -- increased every time `error` is set to a new value, used to check when to re-draw the error editor marks
    -- a manual check is necessary because `errorLoc` is set many times as Elm updates
    , errorCounter : Int
    , settings : Settings.Model
    , viewingSettings : Bool
    }


errorFromRenderState renderState =
    case renderState of
        BattleViewer.Render val ->
            val.viewerState.selectedUnit
                |> Maybe.andThen
                    (\( _, robotOutput ) ->
                        case robotOutput.action of
                            Ok _ ->
                                Nothing

                            Err err ->
                                Just (Data.RobotErrorType err)
                    )

        _ ->
            Nothing


type alias Paths =
    { robot : String
    , publish : String
    , assets : String
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        settings =
            case flags.settings of
                Just encodedSettings ->
                    case Settings.decodeSettings encodedSettings of
                        Ok ok ->
                            ok

                        Err _ ->
                            Settings.default

                Nothing ->
                    Settings.default

        apiContext =
            Api.Context flags.user flags.robot flags.robotId flags.apiPaths

        ( battleViewerModel, battleViewerCmd ) =
            BattleViewer.init apiContext flags.paths.assets True flags.robot
    in
    ( Model
        flags.paths
        apiContext
        flags.code
        flags.lang
        battleViewerModel
        Initial
        (errorFromRenderState battleViewerModel.renderState)
        1
        settings
        False
    , Cmd.map GotRenderMsg battleViewerCmd
    )


type alias Flags =
    { paths : Paths
    , apiPaths : Api.Paths
    , user : String
    , code : String
    , robot : String
    , robotId : Int
    , lang : String
    , settings : Maybe Encode.Value
    }



-- UPDATE


port startEval : Encode.Value -> Cmd msg


port reportDecodeError : String -> Cmd msg


port savedCode : String -> Cmd msg


port saveSettings : Encode.Value -> Cmd msg


type Msg
    = GotOutput Decode.Value
    | GotProgress Decode.Value
    | GotRenderMsg BattleViewer.Msg
    | GotSettingsMsg Settings.Msg
    | CodeChanged String
    | Save
    | Saved (Result Http.Error ())
    | ViewSettings
    | CloseSettings


handleDecodeError : Model -> Decode.Error -> ( Model, Cmd.Cmd msg )
handleDecodeError model error =
    let
        ( newModel, _ ) =
            update (GotRenderMsg BattleViewer.GotInternalError) model
    in
    ( newModel, reportDecodeError <| Decode.errorToString error )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotOutput output ->
            case Data.decodeOutcomeData output of
                Ok data ->
                    let
                        ( newModel, _ ) =
                            update (GotRenderMsg (BattleViewer.GotOutput data)) model
                    in
                    ( { newModel | error = data.errors |> Dict.get "Red" |> Maybe.map Data.OutcomeErrorType, errorCounter = model.errorCounter + 1 }, Cmd.none )

                Err error ->
                    handleDecodeError model error

        GotProgress progress ->
            case Data.decodeProgressData progress of
                Ok data ->
                    update (GotRenderMsg (BattleViewer.GotProgress data)) model

                Err error ->
                    handleDecodeError model error

        Save ->
            let
                codeUpdateCmd =
                    Api.updateRobotCode model.apiContext model.code
                        |> Api.makeRequest Saved
            in
            ( model, Cmd.batch [ codeUpdateCmd, savedCode model.code ] )

        GotRenderMsg renderMsg ->
            let
                ( newBattleViewerModel, renderCmd ) =
                    BattleViewer.update renderMsg model.battleViewerModel
            in
            case renderMsg of
                BattleViewer.Run turnNum ->
                    let
                        encodeCode ( code, lang ) =
                            Encode.object
                                [ ( "code", Encode.string code )
                                , ( "lang", Encode.string lang )
                                ]

                        selfCode =
                            ( model.code, model.lang )

                        maybeOpponentCode =
                            case model.battleViewerModel.opponentSelectState.opponent of
                                OpponentSelect.Robot ( robot, code ) ->
                                    code |> Maybe.map (\c -> ( c, robot.lang ))

                                OpponentSelect.Itself ->
                                    Just selfCode
                    in
                    case maybeOpponentCode of
                        Just opponentCode ->
                            ( { model | battleViewerModel = newBattleViewerModel, error = Nothing }
                            , startEval <|
                                Encode.object
                                    [ ( "code", encodeCode selfCode )
                                    , ( "opponentCode", encodeCode opponentCode )
                                    , ( "turnNum", Encode.int turnNum )
                                    ]
                            )

                        Nothing ->
                            ( { model | battleViewerModel = newBattleViewerModel }, Cmd.none )

                other ->
                    ( case other of
                        BattleViewer.GotRenderMsg (GridViewer.GotGridMsg (Grid.UnitSelected _)) ->
                            { model
                                | battleViewerModel = newBattleViewerModel
                                , error = errorFromRenderState newBattleViewerModel.renderState
                                , errorCounter = model.errorCounter + 1
                            }

                        -- an error can also be set as the battle loads. concretely, if the first turn has an error,
                        -- the robot with that error is automatically selected
                        BattleViewer.GotProgress (_) ->
                            { model
                                | battleViewerModel = newBattleViewerModel
                                , error = errorFromRenderState newBattleViewerModel.renderState
                                , errorCounter = model.errorCounter + 1
                            }

                        BattleViewer.GotRenderMsg GridViewer.ResetSelectedUnit ->
                            { model
                                | battleViewerModel = newBattleViewerModel
                                , error = Nothing
                            }

                        _ ->
                            { model | battleViewerModel = newBattleViewerModel }
                    , Cmd.map GotRenderMsg renderCmd
                    )

        CodeChanged code ->
            ( { model | code = code }, Cmd.none )

        Saved _ ->
            ( { model
                | saveAnimationPhase =
                    case model.saveAnimationPhase of
                        Initial ->
                            One

                        One ->
                            Two

                        Two ->
                            One
              }
            , Cmd.none
            )

        ViewSettings ->
            ( { model | viewingSettings = True }, Cmd.none )

        CloseSettings ->
            ( { model | viewingSettings = False }, saveSettings (Settings.encodeSettings model.settings) )

        GotSettingsMsg settingsMsg ->
            ( { model | settings = Settings.update settingsMsg model.settings }, Cmd.none )



-- SUBSCRIPTIONS


port getOutput : (Decode.Value -> msg) -> Sub msg


port getProgress : (Decode.Value -> msg) -> Sub msg


port getInternalError : (() -> msg) -> Sub msg


port finishedDownloading : (() -> msg) -> Sub msg


port finishedLoading : (() -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ getOutput GotOutput
        , getProgress GotProgress
        , getInternalError (always <| GotRenderMsg BattleViewer.GotInternalError)
        , finishedDownloading (always <| GotRenderMsg BattleViewer.FinishedDownloadingRunner)
        , finishedLoading (always <| GotRenderMsg BattleViewer.FinishedLoadingRunner)
        ]



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "_root-app-root d-flex" ]
        [ div [ class "_ui" ] <|
            if model.viewingSettings then
                [ Settings.view model.settings |> Html.map GotSettingsMsg
                , button [ class "button align-self-center", onClick CloseSettings ] [ text "done" ]
                ]

            else
                [ viewBar model
                , viewEditor model
                ]
        , div [ class "gutter" ] []
        , div [ class "_viewer" ]
            [ Html.map GotRenderMsg <| BattleViewer.view model.battleViewerModel
            ]
        ]


viewBar : Model -> Html Msg
viewBar model =
    div [ class "_bar d-flex justify-content-between align-items-center" ]
        [ div [ class "d-flex align-items-center" ]
            [ p [] [ text "The Garage -- editing ", a [ href model.paths.robot ] [ text model.apiContext.robot ] ]
            , button [ class "button ml-5 mr-3", onClick Save ] [ text "save" ]
            , p
                [ class <|
                    "disappearing-"
                        ++ (case model.saveAnimationPhase of
                                One ->
                                    "one"

                                Two ->
                                    "two"

                                Initial ->
                                    ""
                           )
                , style "visibility" <|
                    case model.saveAnimationPhase of
                        Initial ->
                            "hidden"

                        _ ->
                            "visible"
                ]
                [ text "saved" ]
            , a [ href model.paths.publish ] [ text "ready to publish?" ]
            ]
        , button [ onClick ViewSettings ] [ img [ src <| model.paths.assets ++ "/images/settings.svg" ] [] ]
        ]


viewEditor : Model -> Html Msg
viewEditor model =
    let
        errorAttribute errorDetails =
            case errorDetails.loc of
                Just loc ->
                    [ property "errorLoc" <|
                        Data.errorLocEncoder loc
                    ]

                Nothing ->
                    []
    in
    Html.node "code-editor"
        ([ Html.Events.on "editorChanged" <|
            Decode.map CodeChanged <|
                Decode.at [ "target", "value" ] <|
                    Decode.string
         , Html.Attributes.attribute "code" model.code
         , class "_editor"
         ]
            ++ [ property "errorCounter" (Encode.int model.errorCounter)]
            ++ (case model.error of
                    Just (Data.OutcomeErrorType (Data.InitError errorDetails)) ->
                        errorAttribute errorDetails

                    Just (Data.RobotErrorType (Data.RuntimeError errorDetails)) ->
                        errorAttribute errorDetails

                    _ ->
                        []
               )
        )
        []
