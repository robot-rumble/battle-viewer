module OpponentSelect exposing (Model, Msg(..), Opponent(..), init, update, view)

import Api
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)



-- MODEL


type alias Model =
    { apiContext : Api.Context
    , opponent : Opponent
    , userRobots : List Api.Robot
    , apiError : Maybe String
    }


type Opponent
    = Itself
    | Robot ( Api.Robot, Maybe String )


init : Api.Context -> ( Model, Cmd Msg )
init apiContext =
    ( Model apiContext Itself [] Nothing, Api.getUserRobots apiContext apiContext.user |> Api.makeRequest GotUserRobots )



-- UPDATE


type Msg
    = SelectOpponent Opponent
    | GotUserRobots (Api.Result (List Api.Robot))
    | GotCode (Api.Result String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SelectOpponent opponent ->
            ( { model | opponent = opponent }
            , case opponent of
                Robot ( robot, _ ) ->
                    Api.getRobotCode model.apiContext robot.id |> Api.makeRequest GotCode

                _ ->
                    Cmd.none
            )

        GotUserRobots result ->
            ( case result of
                Ok data ->
                    { model | userRobots = data |> List.filter (\robot -> robot.published && robot.name /= model.apiContext.robot) }

                Err error ->
                    { model | apiError = Just <| Api.errorToString error }
            , Cmd.none
            )

        GotCode result ->
            ( case result of
                Ok code ->
                    { model
                        | opponent =
                            case model.opponent of
                                Robot ( robot, _ ) ->
                                    Robot ( robot, Just code )

                                other ->
                                    other
                    }

                Err error ->
                    { model | apiError = Just <| Api.errorToString error }
            , Cmd.none
            )



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "_opponent-select" ]
        [ case model.apiError of
            Just _ ->
                p [ class "error" ] [ text "Api error! Something broke. Unfortunately, you can't switch your opponent for now, but we're working on this." ]

            Nothing ->
                div [] []
        , button [ onClick <| SelectOpponent Itself ] [ text "Itself" ]
        , div []
            [ p [] [ text "Your published robots" ]
            , div [] <|
                if List.isEmpty model.userRobots then
                    [ p [ class "font-italic" ] [ text "nothing here" ] ]

                else
                    model.userRobots
                        |> List.map
                            (\robot ->
                                button [ onClick <| SelectOpponent (Robot ( robot, Nothing )) ] [ text robot.name ]
                            )
            ]
        ]
