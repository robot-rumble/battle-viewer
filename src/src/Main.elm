port module Main exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode
import Json.Encode as Encode

import Data
import BattleViewerMain

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
    { code : String
    , updatePath : Maybe String
    , renderState : BattleViewerMain.Model
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( Model flags.code flags.updatePath (BattleViewerMain.init flags.totalTurns), Cmd.none )


type alias Flags =
    { code : String
    , totalTurns : Int
    , updatePath : Maybe String
    }

-- UPDATE
port startEval : String -> Cmd msg


port reportDecodeError : String -> Cmd msg


type Msg
    = GotOutput Decode.Value
    | GotProgress Decode.Value
    | GotRenderMsg BattleViewerMain.Msg
    | CodeChanged String
    | Save
    | Saved (Result Http.Error ())


handleDecodeError : Model -> Decode.Error -> ( Model, Cmd.Cmd msg )
handleDecodeError model error =
    let (newModel, _) = update (GotRenderMsg (BattleViewerMain.GotInternalError)) model in
    ( newModel, reportDecodeError <| Decode.errorToString error )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotOutput output ->
            case Data.decodeOutcomeData output of
                Ok data ->
                    update (GotRenderMsg (BattleViewerMain.GotOutput data)) model

                Err error ->
                    handleDecodeError model error

        GotProgress progress ->
            case Data.decodeProgressData progress of
                Ok data ->
                    update (GotRenderMsg (BattleViewerMain.GotProgress data)) model

                Err error ->
                    handleDecodeError model error

        Save ->
            let
                codeUpdateCmd =
                    case model.updatePath of
                        Just path ->
                            Http.post
                                { url = path
                                , body = Http.jsonBody (Encode.object [ ( "code", Encode.string model.code ) ])
                                , expect = Http.expectWhatever Saved
                                }

                        Nothing ->
                            Cmd.none
            in
            (model, codeUpdateCmd )

        GotRenderMsg renderMsg ->
            let cmd = case renderMsg of
                    BattleViewerMain.Run -> startEval model.code
                    _ -> Cmd.none
            in ({ model | renderState = (BattleViewerMain.update renderMsg model.renderState) }, cmd )

        CodeChanged code ->
            ( { model | code = code }, Cmd.none )

        Saved _ ->
            ( model, Cmd.none )


-- SUBSCRIPTIONS


port getOutput : (Decode.Value -> msg) -> Sub msg


port getProgress : (Decode.Value -> msg) -> Sub msg


port getInternalError : (() -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ getOutput GotOutput
        , getProgress GotProgress
        , getInternalError (always <| GotRenderMsg (BattleViewerMain.GotInternalError))
        ]



-- VIEW

view : Model -> Html Msg
view model =
    div [ class "app-root" ] [
        viewEditor model,
        Html.map GotRenderMsg <| BattleViewerMain.view model.renderState
    ]

viewEditor : Model -> Html Msg
viewEditor model =
    Html.node "code-editor"
        ([ Html.Events.on "editorChanged" <|
            Decode.map CodeChanged <|
                Decode.at [ "target", "value" ] <|
                    Decode.string
         , Html.Attributes.attribute "code" model.code
         ]
            --++ (case model.renderState.renderState of
            --        BattleViewerMain.Error error ->
            --            case error.errorLoc of
            --                Just errorLoc ->
            --                    [ property "errorLoc" <|
            --                        Data.errorLocEncoder errorLoc
            --                    ]
            --
            --                Nothing ->
            --                    []
            --
            --        _ ->
            --            []
            --   )
        )
        []
