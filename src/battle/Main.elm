port module Main exposing (..)

import Browser
import Data
import GridViewer
import Html exposing (..)
import Html.Attributes exposing (..)
import Json.Decode as Decode



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
    Maybe GridViewer.Model


port reportDecodeError : String -> Cmd msg


type alias Flags =
    { data : Decode.Value, team : Maybe Data.Team, userOwnsOpponent : Bool, gameMode : String }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        output =
            Data.decodeFullOutcomeData flags.data
    in
    case output of
        Ok outputData ->
            let
                -- we do "- 1" because the battle viewer expects the number of entries
                -- in the data array to be one more than the number of turns
                -- this is because the last entry in the output is treated as an extra entry:
                -- the state of the board after the last turn
                turnNum =
                    List.length outputData.turns - 1

                gridViewerModel =
                    GridViewer.init turnNum flags.team flags.userOwnsOpponent False (Data.decodeGameMode flags.gameMode)
            in
            ( Just
                (List.foldl (\turn -> GridViewer.update (GridViewer.GotTurn turn)) gridViewerModel outputData.turns
                    |> GridViewer.update (GridViewer.GotErrors outputData.errors)
                )
            , Cmd.none
            )

        Err error ->
            ( Nothing, reportDecodeError <| Decode.errorToString error )



-- MSG


type alias Msg =
    GridViewer.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg maybeModel =
    ( Maybe.map (GridViewer.update msg) maybeModel, Cmd.none )



-- SUBSCRIPTIONS


subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "_app-root align-items-center" ] <|
        (case model of
            Just _ ->
                []

            Nothing ->
                [ div [ class "error mb-4" ] [ text "Internal error! Something broke. This is automatically recorded, so please hang tight while we figure this out." ] ]
        )
            ++ [ GridViewer.view model False ]
