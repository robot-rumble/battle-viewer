port module Main exposing (..)

import BattleViewer
import Browser
import Data
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode
import Json.Encode as Encode



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
    , robot : String
    , updatePath : String
    , robotPath : String
    , publishPath : String
    , renderState : BattleViewer.Model
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( Model flags.code
        flags.robot
        flags.updatePath
        flags.robotPath
        flags.publishPath
        (BattleViewer.init flags.totalTurns)
    , Cmd.none
    )


type alias Flags =
    { code : String
    , totalTurns : Int
    , robot : String
    , updatePath : String
    , robotPath : String
    , publishPath : String
    }



-- UPDATE


port startEval : String -> Cmd msg


port reportDecodeError : String -> Cmd msg


type Msg
    = GotOutput Decode.Value
    | GotProgress Decode.Value
    | GotRenderMsg BattleViewer.Msg
    | CodeChanged String
    | Save
    | Saved (Result Http.Error ())


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
                    update (GotRenderMsg (BattleViewer.GotOutput data)) model

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
                    Http.post
                        { url = model.updatePath
                        , body = Http.jsonBody (Encode.object [ ( "code", Encode.string model.code ) ])
                        , expect = Http.expectWhatever Saved
                        }
            in
            ( model, codeUpdateCmd )

        GotRenderMsg renderMsg ->
            let
                cmd =
                    case renderMsg of
                        BattleViewer.Run ->
                            startEval model.code

                        _ ->
                            Cmd.none
            in
            ( { model | renderState = BattleViewer.update renderMsg model.renderState }, cmd )

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
        , getInternalError (always <| GotRenderMsg BattleViewer.GotInternalError)
        ]



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "_app-root d-flex" ]
        [ div [ style "width" "70%" ]
            [ viewBar model
            , div [ class "_editor p-5" ] [ viewEditor model ]
            ]
        , div [ class "_viewer", style "width" "30%" ]
            [ Html.map GotRenderMsg <| BattleViewer.view model.renderState
            ]
        ]


viewBar : Model -> Html Msg
viewBar model =
    div [ class "_bar p-2 d-flex justify-content-between align-items-center" ]
        [ div [ class "d-flex align-items-center" ]
            [ p [] [ text "The Garage -- editing ", a [ href model.robotPath ] [ text model.robot ] ]
            , button [ class "button ml-5", onClick Save ] [ text "save" ]
            ]
        , a [ href model.publishPath ] [ text "ready to publish?" ]
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
