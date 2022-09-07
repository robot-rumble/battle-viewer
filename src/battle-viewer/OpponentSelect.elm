module OpponentSelect exposing (Flags(..), Model(..), Msg(..), NormalFlags, Opponent(..), TutorialFlags, currentChapter, evalInfo, init, opponentName, robotName, update, userOwnsOpponent, view)

import Api
import Array
import Data
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode


onKeyDown : (Int -> msg) -> Attribute msg
onKeyDown msg =
    on "keydown" (Decode.map msg keyCode)



-- MODEL


type Model
    = Normal NormalModel
    | Tutorial TutorialModel


type alias NormalModel =
    { apiContext : Api.Context
    , opponent : Opponent
    , userRobots : List Api.Robot
    , builtinRobots : List Api.Robot
    , apiError : Maybe String
    , searchUser : String
    , searchResult : Maybe (Result String (List Api.Robot))
    , cli : Bool
    }


type alias TutorialModel =
    { data : Data.Tutorial
    , selectedChapter : Int
    }


type Opponent
    = Itself
    | Robot RobotDetails


type alias RobotDetails =
    { robot : Api.Robot

    -- the code is a Maybe so that it is possible to select an opponent and lode the code later
    -- any attempt to eval against an opponent with no code will silently fail
    , code : Maybe String
    }


userOwnsOpponent : Model -> Bool
userOwnsOpponent baseModel =
    case baseModel of
        Normal model ->
            case model.opponent of
                Itself ->
                    True

                Robot opponent ->
                    case opponent.robot.details of
                        Api.Site siteRobot ->
                            case model.apiContext.siteInfo of
                                Just info ->
                                    siteRobot.userId == info.userId

                                Nothing ->
                                    False

                        Api.Local ->
                            True

        Tutorial _ ->
            False


robotName : Model -> String
robotName baseModel =
    case baseModel of
        Normal model ->
            case model.apiContext.siteInfo of
                Just info ->
                    info.robot

                Nothing ->
                    "demo robot"

        Tutorial model ->
            "your robot"


opponentName : Model -> String
opponentName baseModel =
    case baseModel of
        Normal model ->
            case model.opponent of
                Robot robotDetails ->
                    robotDetails.robot.basic.name

                Itself ->
                    "itself"

        Tutorial model ->
            "Chapter " ++ String.fromInt (model.selectedChapter + 1)


currentChapter : TutorialModel -> Maybe Data.Chapter
currentChapter model =
    Array.get model.selectedChapter model.data.chapters


evalInfo : Model -> ( String, String ) -> Maybe ( ( String, String ), Maybe Data.SimulationSettings )
evalInfo baseModel selfEvalInfo =
    case baseModel of
        Normal model ->
            case model.opponent of
                Robot robotDetails ->
                    let
                        lang =
                            case robotDetails.robot.details of
                                Api.Site siteRobot ->
                                    siteRobot.lang

                                -- the CLI stores the language argument on its own
                                Api.Local ->
                                    ""
                    in
                    robotDetails.code |> Maybe.map (\c -> ( ( c, lang ), Nothing ))

                Itself ->
                    Just ( selfEvalInfo, Nothing )

        Tutorial model ->
            currentChapter model |> Maybe.map (\chapter -> ( ( chapter.opponentCode, chapter.opponentLang ), Just chapter.simulationSettings ))


type Flags
    = NormalF NormalFlags
    | TutorialF TutorialFlags


type alias NormalFlags =
    { apiContext : Api.Context
    , cli : Bool
    }


type alias TutorialFlags =
    { data : Data.Tutorial
    }


init : Flags -> ( Model, Cmd Msg )
init baseFlags =
    case baseFlags of
        NormalF { apiContext, cli } ->
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
            ( Normal <| NormalModel apiContext Itself [] [] Nothing "" Nothing cli, Cmd.batch [ getUserRobotsCmd, getBuiltinRobotsCmd ] )

        TutorialF { data } ->
            ( Tutorial <| TutorialModel data 0, Cmd.none )



-- UPDATE


type Msg
    = SelectOpponent ( Bool, Opponent )
    | GotUserRobots (Api.Result (List Api.Robot))
    | GotBuiltinRobots (Api.Result (List Api.Robot))
    | GotCode (Api.Result String)
    | ChangeSearchUser String
    | Search
    | KeyDown Int
    | GotSearchUserRobots (Api.Result (List Api.Robot))
    | SelectChapter Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg baseModel =
    case baseModel of
        Normal model ->
            let
                ( newModel, cmd ) =
                    normalUpdate msg model
            in
            ( Normal newModel, cmd )

        Tutorial model ->
            ( Tutorial <| tutorialUpdate msg model, Cmd.none )


normalUpdate : Msg -> NormalModel -> ( NormalModel, Cmd Msg )
normalUpdate msg model =
    case msg of
        SelectOpponent ( isDev, opponent ) ->
            ( { model | opponent = opponent, searchResult = Nothing }
            , if not model.cli then
                case opponent of
                    Robot robotDetails ->
                        Api.getRobotCode model.apiContext isDev robotDetails.robot.basic.id |> Api.makeRequest GotCode

                    Itself ->
                        Cmd.none

              else
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

        ChangeSearchUser user ->
            ( { model | searchUser = user }, Cmd.none )

        KeyDown key ->
            if key == 13 then
                search model

            else
                ( model, Cmd.none )

        Search ->
            search model

        GotSearchUserRobots result ->
            ( case result of
                Ok data ->
                    { model | searchResult = Just (Ok data) }

                Err _ ->
                    { model | searchResult = Just (Err "User not found") }
            , Cmd.none
            )

        _ ->
            ( model, Cmd.none )


search : NormalModel -> ( NormalModel, Cmd Msg )
search model =
    ( { model | searchResult = Nothing }
    , if not <| String.isEmpty model.searchUser then
        Api.getUserRobots model.apiContext model.searchUser |> Api.makeRequest GotSearchUserRobots

      else
        Cmd.none
    )


tutorialUpdate : Msg -> TutorialModel -> TutorialModel
tutorialUpdate msg model =
    case msg of
        SelectChapter i ->
            { model | selectedChapter = i }

        _ ->
            model



-- VIEW


view : Model -> Html Msg
view baseModel =
    case baseModel of
        Normal model ->
            normalView model

        Tutorial model ->
            tutorialView model


normalView : NormalModel -> Html Msg
normalView model =
    div [ class "_opponent-select" ] <|
        (case model.apiError of
            Just _ ->
                [ p [ class "error" ] [ text "Api error! Something broke. This is automatically recorded, so please hang tight while we figure this out." ] ]

            Nothing ->
                []
        )
            ++ [ button [ class "button", onClick <| SelectOpponent ( True, Itself ) ] [ text "Itself" ] ]
            ++ (case model.apiContext.siteInfo of
                    Just _ ->
                        [ div []
                            [ p [ class "mb-2" ]
                                [ text <|
                                    if model.cli then
                                        "Selected robots"

                                    else
                                        "Your robot drafts"
                                ]
                            , viewRobotsList model.apiContext model.userRobots True
                            ]
                        ]

                    Nothing ->
                        []
               )
            ++ (if model.cli then
                    []

                else
                    [ div []
                        [ p [ class "mb-2" ] [ text "Built-in robots" ]
                        , viewRobotsList model.apiContext model.builtinRobots False
                        ]
                    , div []
                        [ p [ class "mb-2" ] [ text "Search published robots" ]
                        , div [ class "d-flex mb-3" ]
                            [ input [ class "me-3", placeholder "user", value model.searchUser, onInput ChangeSearchUser, onKeyDown KeyDown ] []
                            , button [ class "button", onClick Search ] [ text "find" ]
                            ]
                        , case model.searchResult of
                            Just (Ok robots) ->
                                viewRobotsList model.apiContext robots False

                            Just (Err err) ->
                                div [ class "error" ] [ text err ]

                            Nothing ->
                                div [] []
                        ]
                    ]
               )


viewRobotsList : Api.Context -> List Api.Robot -> Bool -> Html Msg
viewRobotsList apiContext robots isDev =
    if List.isEmpty robots then
        p [ class "font-italic" ] [ text "nothing here" ]

    else
        div [] <|
            List.map
                (\robot ->
                    div [ class "d-flex" ] <|
                        [ button
                            [ class "mb-2 me-3 button"
                            , onClick <| SelectOpponent ( isDev, Robot { robot = robot, code = Nothing } )
                            , disabled
                                (case robot.details of
                                    Api.Site siteRobot ->
                                        not siteRobot.openSource

                                    Api.Local ->
                                        False
                                )
                            ]
                            [ text robot.basic.name ]
                        ]
                            ++ (case robot.details of
                                    Api.Site siteRobot ->
                                        (if siteRobot.openSource then
                                            []

                                         else
                                            [ p [ class "me-3", class "text-grey" ] [ text "(closed source)" ] ]
                                        )
                                            ++ [ a [ href <| Api.urlForViewingRobot apiContext robot.basic.id, target "_blank", class "me-3" ] [ text "view" ] ]
                                            ++ (case apiContext.siteInfo of
                                                    Just info ->
                                                        if siteRobot.userId == info.userId then
                                                            [ a [ href <| Api.urlForEditingRobot apiContext robot.basic.id, target "_blank" ] [ text "edit" ] ]

                                                        else
                                                            []

                                                    Nothing ->
                                                        []
                                               )

                                    Api.Local ->
                                        []
                               )
                )
                robots


tutorialView : TutorialModel -> Html Msg
tutorialView model =
    div [ class "_opponent-select" ]
        [ h3 [ class "mb-3" ]
            [ text "Chapters"
            ]
        , div []
            (Array.indexedMap
                (\i chapter ->
                    div [ class "d-flex mb-2" ]
                        [ p [ class "me-4" ] [ text chapter.title ]
                        , button [ class "button", onClick <| SelectChapter i, disabled <| i == model.selectedChapter ] [ text "select" ]
                        ]
                )
                model.data.chapters
                |> Array.toList
            )
        ]
