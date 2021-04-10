module Api exposing
    ( BasicRobot
    , Context
    , Paths
    , Result
    , Robot
    , RobotDetails(..)
    , RobotId(..)
    , UserId(..)
    , errorToString
    , getRobotCode
    , getUserRobots
    , makeRequest
    , unwrapRobotId
    , unwrapUserId
    , updateRobotCode
    , urlForEditingRobot
    , urlForViewingRobot
    )

import Http exposing (Part, stringPart)
import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (required)
import Url.Builder exposing (crossOrigin)



-- CTX


type alias Context =
    { user : String
    , userId : UserId
    , robot : String
    , robotId : RobotId
    , paths : Paths
    }



-- HTTP


type alias Error =
    Http.Error


type alias Result val =
    Result.Result Error val


errorToString : Error -> String
errorToString error =
    case error of
        Http.BadUrl url ->
            "The URL " ++ url ++ " was invalid"

        Http.Timeout ->
            "Unable to reach the server, try again"

        Http.NetworkError ->
            "Unable to reach the server, check your network connection"

        Http.BadStatus 500 ->
            "The server had a problem, try again later"

        Http.BadStatus 400 ->
            "Verify your information and try again"

        Http.BadStatus _ ->
            "Unknown error"

        Http.BadBody errorMessage ->
            errorMessage


type alias Endpoint val =
    ( String, List String, Decoder val )


type alias Paths =
    { getUserRobots : String
    , getRobotCode : String
    , updateRobotCode : String
    , viewRobot : String
    , editRobot : String
    }


type Request val
    = Get (Endpoint val)
    | Post (Endpoint val) (List Part)


generateUrl : String -> List String -> String
generateUrl basePath pathSegments =
    crossOrigin basePath pathSegments []


makeRequest : (Result val -> msg) -> Request val -> Cmd msg
makeRequest msg request =
    case request of
        Get ( basePath, pathSegments, decoder ) ->
            Http.get
                { url = generateUrl basePath pathSegments
                , expect = Http.expectJson msg decoder
                }

        Post ( basePath, pathSegments, decoder ) parts ->
            Http.post
                { url = generateUrl basePath pathSegments
                , expect = Http.expectJson msg decoder
                , body = Http.multipartBody parts
                }



-- ID DATA TYPES


type alias Id =
    Int


id : Decoder Id
id =
    int


type UserId
    = UserId Id


unwrapUserId userId =
    case userId of
        UserId intId ->
            intId


type RobotId
    = RobotId Id


unwrapRobotId userId =
    case userId of
        RobotId intId ->
            intId



-- ROBOT DATA TYPES


type alias Robot =
    { basic : BasicRobot
    , details : RobotDetails
    }


robotDecoder : Decoder Robot
robotDecoder =
    basicRobotDecoder
        |> andThen
            (\basicRobot ->
                objDetailsDecoder
                    |> andThen
                        (\robotDetails ->
                            Json.Decode.succeed { basic = basicRobot, details = robotDetails }
                        )
            )


type alias BasicRobot =
    { id : RobotId
    , name : String
    }


basicRobotDecoder : Decoder BasicRobot
basicRobotDecoder =
    succeed BasicRobot
        |> required "id" (id |> map RobotId)
        |> required "name" string


type RobotDetails
    = Site SiteRobot
    | Local


type alias SiteRobot =
    { id : RobotId
    , userId : UserId
    , name : String
    , lang : String
    , published : Bool
    }


objDetailsDecoder : Decoder RobotDetails
objDetailsDecoder =
    oneOf [ siteRobotDecoder, localRobotDecoder ]


siteRobotDecoder : Decoder RobotDetails
siteRobotDecoder =
    succeed SiteRobot
        |> required "id" (id |> map RobotId)
        |> required "userId" (id |> map UserId)
        |> required "name" string
        |> required "lang" string
        |> required "published" bool
        |> map Site


localRobotDecoder : Decoder RobotDetails
localRobotDecoder =
    succeed Local



-- ROUTES


getUserRobots : Context -> String -> Request (List Robot)
getUserRobots context user =
    Get ( context.paths.getUserRobots, [ user ], list robotDecoder )


getRobotCode : Context -> RobotId -> Request String
getRobotCode context robotId =
    Get ( context.paths.getRobotCode, [ String.fromInt (unwrapRobotId robotId) ], string )


updateRobotCode : Context -> String -> Request ()
updateRobotCode context code =
    Post ( context.paths.updateRobotCode, [ String.fromInt (unwrapRobotId context.robotId) ], succeed () )
        [ stringPart "code" code ]


urlForViewingRobot : Context -> RobotId -> String
urlForViewingRobot context robotId =
    generateUrl context.paths.viewRobot [ String.fromInt (unwrapRobotId robotId) ]


urlForEditingRobot : Context -> RobotId -> String
urlForEditingRobot context robotId =
    generateUrl context.paths.editRobot [ String.fromInt (unwrapRobotId robotId) ]
