port module Main exposing (..)

import Api
import BattleViewer
import Browser
import Data
import DefaultCode exposing (loadDefaultCode)
import Dict
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
    { apiContext : Api.Context
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
    , team : Maybe Data.Team
    }


errorFromRenderState renderState =
    case renderState of
        BattleViewer.Render ( _, viewerState ) ->
            viewerState.selectedUnit
                |> Maybe.andThen
                    (\unit ->
                        case unit.action of
                            Ok _ ->
                                Nothing

                            Err err ->
                                if unit.isOurTeam then
                                    Just (Data.RobotErrorType err)

                                else
                                    Nothing
                    )

        _ ->
            Nothing


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
            Api.contextFlagtoContext flags.apiContext

        ( battleViewerModel, battleViewerCmd ) =
            BattleViewer.init apiContext True flags.team

        -- if in demo, the code will be an empty string
        -- the default code needs to be stored on the level of elm because ultimately
        -- elm calls the battle execution and so when the language changes
        -- elm needs to have the new code
        code =
            if String.isEmpty flags.code then
                loadDefaultCode flags.lang

            else
                flags.code
    in
    ( Model
        apiContext
        code
        flags.lang
        battleViewerModel
        Initial
        (errorFromRenderState battleViewerModel.renderState)
        1
        settings
        False
        flags.team
    , Cmd.map GotRenderMsg battleViewerCmd
    )


type alias Flags =
    { code : String
    , lang : String
    , apiContext : Api.ContextFlag
    , settings : Maybe Encode.Value
    , team : Maybe Data.Team
    }



-- UPDATE


port startEval : Encode.Value -> Cmd msg


port reportDecodeError : String -> Cmd msg


port reportApiError : String -> Cmd msg


port savedCode : String -> Cmd msg


port saveSettings : Encode.Value -> Cmd msg


port selectLang : String -> Cmd msg


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
    | SelectLang String


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

                        maybeOutcomeError =
                            model.team |> Maybe.andThen (\team -> data.errors |> Dict.get team |> Maybe.map Data.OutcomeErrorType)
                    in
                    let
                        error =
                            case model.error of
                                -- if there is already a runtime error being displayed, don't overwrite it
                                Just oldError ->
                                    Just oldError

                                Nothing ->
                                    maybeOutcomeError
                    in
                    ( { newModel
                        | error = error
                        , errorCounter = model.errorCounter + 1
                      }
                    , Cmd.none
                    )

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
                    case model.apiContext.siteInfo of
                        Just info ->
                            Api.updateRobotCode model.apiContext info.robotId model.code
                                |> Api.makeRequest Saved

                        Nothing ->
                            Cmd.none
            in
            ( model, Cmd.batch [ codeUpdateCmd, savedCode model.code ] )

        GotRenderMsg renderMsg ->
            let
                ( newBattleViewerModel, renderCmd ) =
                    BattleViewer.update renderMsg model.battleViewerModel
            in
            let
                ( newModel, newCmd ) =
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
                                        OpponentSelect.Robot robotDetails ->
                                            let
                                                lang =
                                                    case robotDetails.robot.details of
                                                        Api.Site siteRobot ->
                                                            siteRobot.lang

                                                        -- the CLI stores the language argument on its own
                                                        Api.Local ->
                                                            ""
                                            in
                                            robotDetails.code |> Maybe.map (\c -> ( c, lang ))

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
                                BattleViewer.GotRenderMsg GridViewer.ResetSelectedUnit ->
                                    { model
                                        | battleViewerModel = newBattleViewerModel
                                        , error = Nothing
                                    }

                                -- an error can be set on a turn/slider change or unit selection
                                BattleViewer.GotRenderMsg _ ->
                                    { model
                                        | battleViewerModel = newBattleViewerModel
                                        , error = errorFromRenderState newBattleViewerModel.renderState
                                        , errorCounter = model.errorCounter + 1
                                    }

                                -- an error can also be set automatically on an initial load if one of the robots in the
                                -- first turn has a runtime exception
                                BattleViewer.GotProgress _ ->
                                    { model
                                        | battleViewerModel = newBattleViewerModel
                                        , error = errorFromRenderState newBattleViewerModel.renderState
                                        , errorCounter = model.errorCounter + 1
                                    }

                                _ ->
                                    { model | battleViewerModel = newBattleViewerModel }
                            , Cmd.map GotRenderMsg renderCmd
                            )
            in
            let
                reportApiErrorCmd =
                    case newBattleViewerModel.apiError of
                        Just error ->
                            reportApiError error

                        Nothing ->
                            Cmd.none
            in
            ( newModel, Cmd.batch [ newCmd, reportApiErrorCmd ] )

        CodeChanged code ->
            let
                _ =
                    Debug.log "code" code
            in
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

        -- when the user changes the language the code needs to also change
        SelectLang lang ->
            ( { model | lang = lang, code = loadDefaultCode lang }, selectLang lang )



-- SUBSCRIPTIONS


port getOutput : (Decode.Value -> msg) -> Sub msg


port getProgress : (Decode.Value -> msg) -> Sub msg


port getInternalError : (() -> msg) -> Sub msg


port finishedDownloading : (() -> msg) -> Sub msg


port finishedLoading : (() -> msg) -> Sub msg


port getTooLong : (() -> msg) -> Sub msg


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
            (case model.apiContext.siteInfo of
                Just info ->
                    [ p [] [ text "The Garage -- editing ", a [ href <| Api.urlForViewingRobot model.apiContext info.robotId ] [ text info.robot ] ]
                    , button [ class "button ml-4", onClick Save ] [ text "save" ]
                    , p
                        [ class "mx-3"
                        , class <|
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
                    ]

                Nothing ->
                    [ p [ class "mr-5" ] [ text "The Garage DEMO" ]
                    , p [ class "mr-3" ] [ text <| "Change language (will erase): " ]
                    , div [ class "d-flex" ]
                        ([ "Python", "Javascript" ]
                            |> List.map
                                (\lang ->
                                    button [ class "button mr-2", onClick (SelectLang lang) ] [ text lang ]
                                )
                        )
                    ]
            )
        , div [ class "d-flex align-items-center" ]
            [ case model.apiContext.siteInfo of
                Just _ ->
                    a [ class "mr-3", href <| Api.urlForPublishing model.apiContext, target "_blank" ] [ text "publish to a board" ]

                Nothing ->
                    div [] []
            , a [ class "mr-4", href "https://rr-docs.readthedocs.io/en/latest/", target "_blank" ] [ text "docs" ]
            , div [ class "_img-settings", onClick ViewSettings ] []
            ]
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
        ([ class "_editor"
         , Html.Events.on "editorChanged" <|
            Decode.map CodeChanged <|
                Decode.at [ "detail" ] <|
                    Decode.string
         , property "setCode" (Encode.string model.code)
         , property "setLang" (Encode.string model.lang)
         , property "settings" (Settings.encodeSettings model.settings)
         ]
            ++ [ property "errorCounter" (Encode.int model.errorCounter) ]
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
