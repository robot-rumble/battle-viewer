module OpponentSelect exposing (Model, Msg(..), Opponent(..), init, update, userOwnsOpponent, view)

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
    | Robot RobotDetails


type alias RobotDetails =
    { robot : Api.Robot
    , code : Maybe String
    }


userOwnsOpponent : Model -> Api.UserId -> Bool
userOwnsOpponent model userId =
    case model.opponent of
        Itself ->
            True

        Robot opponent ->
            case opponent.robot.details of
                Api.Site siteRobot ->
                    siteRobot.userId == userId

                Api.Local ->
                    True


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
                Robot robotDetails ->
                    Api.getRobotCode model.apiContext robotDetails.robot.basic.id |> Api.makeRequest GotCode

                _ ->
                    Cmd.none
            )

        GotUserRobots result ->
            ( case result of
                Ok data ->
                    { model
                        | userRobots =
                            data
                                |> List.filter
                                    (\robot ->
                                        case robot.details of
                                            -- if a robot does not belong to the user, only show it if it's published
                                            Api.Site siteRobot ->
                                                robot.basic.name
                                                    /= model.apiContext.robot
                                                    && (siteRobot.userId == model.apiContext.userId || siteRobot.published)

                                            Api.Local ->
                                                True
                                    )
                    }

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
                                Robot robotDetails ->
                                    Robot { robotDetails | code = Just code }

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
    div [ class "_opponent-select" ] <|
        (case model.apiError of
            Just _ ->
                [ p [ class "error" ] [ text "Api error! Something broke. Unfortunately, you can't switch your opponent for now, but we're working on this." ] ]

            Nothing ->
                []
        )
            ++ [ button [ class "button", onClick <| SelectOpponent Itself ] [ text "Itself" ]
               , div []
                    [ p [ class "mb-2" ] [ text "Your robots" ]
                    , div [] <|
                        if List.isEmpty model.userRobots then
                            [ p [ class "font-italic" ] [ text "nothing here" ] ]

                        else
                            model.userRobots
                                |> List.map
                                    (\robot ->
                                        div [ class "d-flex" ] <|
                                            [ button
                                                [ class "mb-2 mr-3 button"
                                                , onClick <| SelectOpponent (Robot { robot = robot, code = Nothing })
                                                ]
                                                [ text robot.basic.name ]
                                            ]
                                                ++ (case robot.details of
                                                        Api.Site _ ->
                                                            [ a [ href <| Api.urlForViewingRobot model.apiContext robot.basic.id, target "_blank", class "mr-3" ] [ text "view" ]
                                                            , a [ href <| Api.urlForEditingRobot model.apiContext robot.basic.id, target "_blank" ] [ text "edit" ]
                                                            ]

                                                        Api.Local ->
                                                            []
                                                   )
                                    )
                    ]
               ]
