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
    , builtinRobots : List Api.Robot
    , apiError : Maybe String
    }


type Opponent
    = Itself
    | Robot RobotDetails


type alias RobotDetails =
    { robot : Api.Robot
    , code : Maybe String
    }


userOwnsOpponent : Model -> Api.Context -> Bool
userOwnsOpponent model apiContext =
    case model.opponent of
        Itself ->
            True

        Robot opponent ->
            case opponent.robot.details of
                Api.Site siteRobot ->
                    case apiContext.siteInfo of
                        Just info ->
                            siteRobot.userId == info.userId

                        Nothing ->
                            False

                Api.Local ->
                    True


init : Api.Context -> ( Model, Cmd Msg )
init apiContext =
    let
        getUserRobotsCmd =
            case apiContext.siteInfo of
                Just info ->
                    Api.getUserRobots apiContext info.user |> Api.makeRequest GotUserRobots

                Nothing ->
                    Cmd.none

        getBuiltinRobotsCmd =
            Api.getBuiltinRobots apiContext |> Api.makeRequest GotBuiltinRobots
    in
    ( Model apiContext Itself [] [] Nothing, Cmd.batch [ getUserRobotsCmd, getBuiltinRobotsCmd ] )



-- UPDATE


type Msg
    = SelectOpponent Opponent
    | GotUserRobots (Api.Result (List Api.Robot))
    | GotBuiltinRobots (Api.Result (List Api.Robot))
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
            case model.apiContext.siteInfo of
                Just info ->
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
                                                            /= info.robot
                                                            && (siteRobot.userId == info.userId || siteRobot.published)

                                                    Api.Local ->
                                                        True
                                            )
                            }

                        Err error ->
                            { model | apiError = Just <| Api.errorToString error }
                    , Cmd.none
                    )

                -- this Msg can not occur if siteInfo is Nothing
                Nothing ->
                    ( model, Cmd.none )

        GotBuiltinRobots result ->
            ( case result of
                Ok robots ->
                    { model | builtinRobots = robots }

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
                [ p [ class "error" ] [ text "Api error! Something broke. This is automatically recorded, so please hang tight while we figure this out." ] ]

            Nothing ->
                []
        )
            ++ [ button [ class "button", onClick <| SelectOpponent Itself ] [ text "Itself" ]
               , div []
                    [ p [ class "mb-2" ] [ text "Your robots" ]
                    , viewRobotsList model.apiContext model.userRobots
                    ]
               , div []
                    [ p [ class "mb-2" ] [ text "Built-in robots" ]
                    , viewRobotsList model.apiContext model.builtinRobots
                    ]
               ]


viewRobotsList : Api.Context -> List Api.Robot -> Html Msg
viewRobotsList apiContext robots =
    if List.isEmpty robots then
        p [ class "font-italic" ] [ text "nothing here" ]

    else
        div [] <|
            List.map
                (\robot ->
                    div [ class "d-flex" ] <|
                        [ button
                            [ class "mb-2 mr-3 button"
                            , onClick <| SelectOpponent (Robot { robot = robot, code = Nothing })
                            ]
                            [ text robot.basic.name ]
                        ]
                            ++ (case robot.details of
                                    Api.Site siteRobot ->
                                        [ a [ href <| Api.urlForViewingRobot apiContext robot.basic.id, target "_blank", class "mr-3" ] [ text "view" ]
                                        , case apiContext.siteInfo of
                                            Just info ->
                                                if siteRobot.userId == info.userId then
                                                    a [ href <| Api.urlForEditingRobot apiContext robot.basic.id, target "_blank" ] [ text "edit" ]

                                                else
                                                    div [] []

                                            Nothing ->
                                                div [] []
                                        ]

                                    Api.Local ->
                                        []
                               )
                )
                robots
