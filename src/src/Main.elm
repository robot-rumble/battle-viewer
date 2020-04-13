port module Main exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Array exposing (Array)

import Dict

import Data
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
    , renderState : RenderState
    , totalTurns : Int
    , updatePath : Maybe String
    , logOutput : String
    }

type RenderState = Initializing | Render RenderStateVal | Error Data.Error | NoRender | InternalError

type alias RenderStateVal =
   { turns : Array Data.State
   , current_turn_num : Int
   }



init : Flags -> ( Model, Cmd Msg )
init flags =
    (Model flags.code NoRender flags.totalTurns flags.updatePath "", Cmd.none )


type alias Flags =
    { totalTurns: Int
    , updatePath: Maybe String
    , code: String
    }


-- UPDATE


port startEval : String -> Cmd msg
port reportDecodeError : String -> Cmd msg

type Msg
    = GotOutput Decode.Value
    | GotProgress Decode.Value
    | GotError Decode.Value
    | Run
    | GotRenderMsg RenderMsg
    | CodeChanged String
    | GotInternalError
    | Saved (Result Http.Error ())
    | GotLog String

type RenderMsg = ChangeTurn Direction
type Direction = Next | Previous

handleDecodeError : Model -> Decode.Error -> (Model, Cmd.Cmd msg)
handleDecodeError model error =
  ( { model | renderState = InternalError }, reportDecodeError <| Decode.errorToString error )

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotOutput output ->
          case Data.decodeOutcome output of
            Ok _ ->
              (model, Cmd.none)

            Err error ->
                handleDecodeError model error

        GotProgress progress ->
          case Data.decodeProgress progress of
            Ok turnState ->
              ( { model | renderState = case model.renderState of
                  Render renderState -> Render { renderState | turns = Array.push turnState renderState.turns }
                  _ -> Render { turns = Array.fromList [turnState], current_turn_num = 0 }
              }, Cmd.none )

            Err error ->
                handleDecodeError model error

        GotError rawError ->
          case Data.decodeError rawError of
            Ok error ->
              ( { model | renderState = Error error }, Cmd.none )

            Err decodeError ->
                handleDecodeError model decodeError

        GotLog value ->
            ( { model | logOutput = model.logOutput ++ value }, Cmd.none )

        Run ->
            let codeUpdateCmd = case model.updatePath of
                    Just (path) ->
                        Http.post({
                            url = path,
                            body = Http.jsonBody(Encode.object [ ("code", Encode.string model.code) ] ),
                            expect = Http.expectWhatever Saved
                        })
                    Nothing -> Cmd.none
            in
            ( { model | renderState = Initializing }, Cmd.batch [codeUpdateCmd, startEval model.code] )


        GotRenderMsg renderMsg ->
            case model.renderState of
                Render state -> ( { model | renderState = Render <| updateRender renderMsg state }, Cmd.none )
                _ -> ( model, Cmd.none )

        CodeChanged code ->
            ( { model | code = code }, Cmd.none )

        GotInternalError ->
            ( { model | renderState = InternalError }, Cmd.none )

        Saved _ -> ( model, Cmd.none )

updateRender : RenderMsg -> RenderStateVal -> RenderStateVal
updateRender msg model =
    case msg of
        ChangeTurn dir -> ( { model | current_turn_num = model.current_turn_num +
            case dir of
                Next ->
                    if model.current_turn_num == Array.length model.turns - 1
                    then 0 else 1
                Previous ->
                    if model.current_turn_num == 0
                    then 0 else -1
            } )


-- SUBSCRIPTIONS

port getOutput : (Decode.Value -> msg) -> Sub msg
port getProgress : (Decode.Value -> msg) -> Sub msg
port getError : (Decode.Value -> msg) -> Sub msg
port getInternalError : (() -> msg) -> Sub msg
port getLog : (String -> msg) -> Sub msg

subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch [
        getOutput GotOutput,
        getProgress GotProgress,
        getError GotError,
        getInternalError (always GotInternalError),
        getLog GotLog
    ]

-- VIEW


to_perc : Float -> String
to_perc float =
    String.fromFloat float ++ "%"



view : Model -> Html Msg
view model =
    viewRobot model

viewRobot : Model -> Html Msg
viewRobot model =
   div [ class "elm-renderer" ]
        [ div [ class "main" ]
            [ viewEditor model
            , viewGame model
            ]
        , viewLog model
        ]

viewLog : Model -> Html Msg
viewLog model =
    let errorMessage = case model.renderState of
            Error error -> Just(error.message)
            _ -> Nothing
    in
    textarea
        [ readonly True
        , class "log"
        , class <| case errorMessage of
            Just(_) -> "error"
            Nothing -> ""
        ]
        [ text <| case errorMessage of
            Just(error) -> error
            Nothing -> model.logOutput
        ]

viewEditor : Model -> Html Msg
viewEditor model =
    Html.node "code-editor"
        ([ Html.Events.on "editorChanged" <|
            Decode.map CodeChanged <|
                Decode.at [ "target", "value" ] <|
                    Decode.string
        , Html.Attributes.attribute "code" model.code
        , style "width" "60%"
        , class "pr-6"
        ] ++ case model.renderState of
            Error error ->
                case error.errorLoc of
                Just errorLoc ->
                    [property "errorLoc" <|
                        Data.errorLocEncoder errorLoc]
                Nothing -> []
            _ -> []
        )
        []

viewGame : Model -> Html Msg
viewGame model =
    div [ style "width" "40%"
        , style "max-width" "500px"
        ]
        [ viewGameBar model
        , viewGameViewer model
        ]


isLoading : Model -> Bool
isLoading model =
    case model.renderState of
        Render render -> Array.length render.turns /= model.totalTurns
        Initializing -> True
        _ -> False

viewGameBar : Model -> Html Msg
viewGameBar model =
    let loading = isLoading model
        loadingBarPerc = if isLoading model then case model.renderState of
                Render render ->
                    let totalTurns = Array.length render.turns in
                    Just((toFloat totalTurns) / (toFloat model.totalTurns) * 100)
                _ -> Just(0)
            else Nothing
    in
    div [ class "game-bar", class "mb-3" ] [
        case loadingBarPerc of
            Just(perc) ->
                div [class "progress", style "width" <| to_perc perc] []
            Nothing -> div [] []
        , div [ class "d-flex justify-content-between" ]
            [ div [ class "d-flex" ]
                [ button
                    [onClick Run, class "button mr-4"
                    -- hide button through CSS to preserve bar height
                    , style "visibility" <| if loading then "hidden" else "visible"
                    ] [text "run"]
                , viewArrows model
                ]
            , case model.renderState of
                -- don't show at very beginning
                NoRender -> div [] []
                -- one frame of not showing to restart animation
                Initializing -> p [] [ text "Initializing..." ]
                _ -> p [ class "disappearing" ] [ text "Saved." ]
            ]
    ]

viewArrows : Model -> Html Msg
viewArrows model =
    case model.renderState of
        Render state ->
            div [class "d-flex justify-content-center align-items-center"]
              [ button
                    [onClick <| GotRenderMsg (ChangeTurn Previous)
                    , disabled (state.current_turn_num == 0)
                    , class "arrow-button"
                    ] [text "\u{2190}"]
              , div [style "width" "5rem", class "text-center"] [text <| "turn " ++ String.fromInt (state.current_turn_num + 1)]
              , button
                    [onClick <| GotRenderMsg (ChangeTurn Next)
                    , disabled (state.current_turn_num == Array.length state.turns - 1)
                    , class "arrow-button"
                    ] [text "\u{2192}"]
              ]
        _ -> div [] []

viewGameViewer : Model -> Html Msg
viewGameViewer model =
    case model.renderState of
        Render state ->
            case Array.get state.current_turn_num state.turns of
               Just turn -> gameRenderer (gameObjs turn)
               Nothing -> div [] [text "Invalid turn."]

        InternalError ->
            div []
                [ gameRenderer []
                , p [class "internal-error", class "mt-3"] [text "Internal Error! Please try again later."]
                ]

        _ ->
            gameRenderer []


map_size = 19
max_health = 5

gameObjs : Data.State -> List (Html Msg)
gameObjs state =
    Dict.values state.objs
    |> List.map (\(basic, details) ->
        let (x, y) = basic.coords in
        div ([ class "obj"
             , class <| String.fromInt basic.id
             , style "grid-column" <| String.fromInt (x + 1)
             , style "grid-row" <| String.fromInt (y + 1)
            ] ++ (
             case details of
                Data.UnitDetails unit ->
                   [ class "unit"
                   , class <| "team-" ++ unit.team
                   ]
                Data.TerrainDetails terrain ->
                   [ class "terrain"
                   , class <| "type-" ++ (
                      case terrain.type_ of
                         Data.Wall -> "wall"
                      )
                   ]
             ))
            [
             case details of
                Data.UnitDetails unit ->
                   let health_perc = (toFloat unit.health) / (toFloat max_health) * 100
                   in
                   div
                      [ class "health-bar"
                      , style "width" <| to_perc health_perc
                      , style "height" <| to_perc health_perc
                      ] []
                _ -> div [] []
            ]

    )

gameGrid : List (Html Msg)
gameGrid =
    List.append
        (List.range 1 map_size |> List.map (\y ->
            div [class "grid-row", style "grid-area" <| "1 / " ++ (String.fromInt y) ++ "/ end / auto"] []
        ))
        (List.range 1 map_size |> List.map (\x ->
            div [class "grid-col", style "grid-area" <| (String.fromInt x) ++ "/ 1 / auto / end"] []
        ))


-- accepts divs to display in the renderer
gameRenderer : List (Html Msg) -> Html Msg
gameRenderer divs =
    let gridTemplateRows = "repeat(" ++ String.fromInt map_size ++ ", 1fr)"
        gridTemplateColumns = "repeat(" ++ String.fromInt map_size ++ ", 1fr)"
    in
    div [class "renderer-wrapper"] [
        div [class "renderer"
            , style "grid-template-rows" gridTemplateRows
            , style "grid-template-columns" gridTemplateColumns
            ] <| List.append (gameGrid) divs
    ]
