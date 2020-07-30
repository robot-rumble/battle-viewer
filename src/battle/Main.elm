module Main exposing (..)

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


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        output =
            Data.decodeFullOutcomeData flags.data
    in
    ( case output of
        Ok outputData ->
            let
                turnNum =
                    List.length outputData.turns

                gridViewerModel =
                    GridViewer.init turnNum flags.team
            in
            Just
                (List.foldl (\turn -> GridViewer.update (GridViewer.GotTurn turn)) gridViewerModel outputData.turns
                    |> GridViewer.update (GridViewer.GotErrors outputData.errors)
                )

        Err _ ->
            Nothing
    , Cmd.none
    )


type alias Flags =
    { data : Decode.Value, team : Maybe Data.Team }



-- MSG


type alias Msg =
    GridViewer.Msg


update msg maybeModel =
    ( Maybe.map (GridViewer.update msg) maybeModel, Cmd.none )



-- SUBSCRIPTIONS


subscriptions _ =
    Sub.none



-- VIEW


view model =
    div [ class "_app-root align-items-center" ] [ GridViewer.view model ]
