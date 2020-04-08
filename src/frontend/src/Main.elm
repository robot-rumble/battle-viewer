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

type RenderState = Loading Int | Render RenderStateVal | Error Data.Error | NoRender | InternalError

type alias RenderStateVal =
   { turns : Array Data.State
   , current_turn_num : Int
   }



init : Flags -> ( Model, Cmd Msg )
init flags =
    (Model "" NoRender flags.totalTurns flags.updatePath "", Cmd.none )


type alias Flags =
    { totalTurns: Int
    , updatePath: Maybe String
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
            ({ model | renderState = Loading 0 }, Cmd.batch [codeUpdateCmd, startEval model.code])


        GotRenderMsg renderMsg ->
            case model.renderState of
                Render state -> ( { model | renderState = Render <| updateRender renderMsg state }, Cmd.none )
                _ -> ( model, Cmd.none )

        CodeChanged code ->
            ( { model | code = code }, Cmd.none )

        GotInternalError ->
            ( { model | renderState = InternalError }, Cmd.none )

        Saved _ -> ( model, Cmd.none )

        GotLog value ->
            ( { model | logOutput = model.logOutput ++ value }, Cmd.none )

updateRender : RenderMsg -> RenderStateVal -> RenderStateVal
updateRender msg model =
    case msg of
        ChangeTurn dir -> ( { model | current_turn_num = model.current_turn_num +
            case dir of
                Next -> 1
                Previous -> -1
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
    viewUI model

viewUI : Model -> Html Msg
viewUI model =
    div []
        [viewRobot model]

viewRobot : Model -> Html Msg
viewRobot model =
   div []
        [ p [ class "mt-5"
            , class "w-75"
            , class "mx-auto"
            ] [text "Welcome to Robot Rumble! This demo allows you to code a robot and run it against itself. The robot's code is a function that returns the type and direction of an action. The arena on the right is a way to battle the robot against itself. The code is open source at https://github.com/chicode/robot-rumble."]
        , div
          [ class "d-flex"
          , class "justify-content-around"
          , class "mt-6"
          , class "mx-6"
          ] [ viewEditor model
            , viewGame model
            ]
        , div [ class "mt-2", class "mx-7" ]
          [ textarea
            [ readonly True 
            , class "w-100"
            , class "border-0"
            ] [ text model.logOutput ]
          ]
         ]

viewEditor : Model -> Html Msg
viewEditor model =
    Html.node "code-editor"
        ([ Html.Events.on "editorChanged" <|
            Decode.map CodeChanged <|
                Decode.at [ "target", "value" ] <|
                    Decode.string
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


viewGameBar : Model -> Html Msg
viewGameBar model =
    div [ class "progress-holder" ]
        [ case model.renderState of
            Loading turn ->
                let progress_perc = (toFloat turn) / (toFloat model.totalTurns) * 100 in
                div [class "progress", class "mb-3", style "width" <| to_perc progress_perc] []
            _ -> div [] []
           ,  button [onClick Run, class "button", class "mb-3"
                 , style "visibility" <|
                     case model.renderState of
                        Loading turn -> "hidden"
                        _ -> "visible"
                 ] [text "run"]

        ]

viewGameViewer : Model -> Html Msg
viewGameViewer model =
    case model.renderState of
        Render state ->
            let game =
                    case Array.get state.current_turn_num state.turns of
                       Just turn -> gameRenderer (gameObjs turn)
                       Nothing -> div [] [text "Invalid turn."]
            in
            div []
                [ game
                , div [class "d-flex", class "justify-content-center", class "mt-3"]
                  [ button
                        [onClick <| GotRenderMsg (ChangeTurn Previous)
                        , disabled (state.current_turn_num == 0)
                        , class "arrow-button"
                        ] [text "\u{2190}"]
                  , div [style "width" "6rem", class "text-center"] [text <| "turn " ++ String.fromInt (state.current_turn_num + 1)]
                  , button
                        [onClick <| GotRenderMsg (ChangeTurn Next)
                        , disabled (state.current_turn_num == Array.length state.turns - 1)
                        , class "arrow-button"
                        ] [text "\u{2192}"]
                  ]
            ]

        Error error ->
            div []
                [ gameRenderer []
                , p [class "error", class "mt-3", class "ws-pre"] [text error.message]
                ]

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
