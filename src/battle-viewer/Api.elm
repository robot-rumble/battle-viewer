module Api exposing
    ( BasicRobot
    , Context
    , ContextFlag
    , Paths
    , Result
    , Robot
    , RobotDetails(..)
    , RobotId(..)
    , UserId(..)
    , contextFlagtoContext
    , errorToString
    , getBuiltinRobots
    , getRobotCode
    , getUserRobots
    , makeRequest
    , unwrapRobotId
    , unwrapUserId
    , updateRobotCode
    , urlForAsset
    , urlForEditingRobot
    , urlForPublishing
    , urlForViewingRobot
    , urlForViewingUser
    )

import Http exposing (Part, stringPart)
import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (required)
import Url.Builder exposing (crossOrigin)



-- CTX


type alias SiteInfoFlag =
    { user : String
    , userId : Int
    , robot : String
    , robotId : Int
    }


type alias SiteInfo =
    { user : String
    , userId : UserId
    , robot : String
    , robotId : RobotId
    }


type alias ContextFlag =
    { siteInfo : Maybe SiteInfoFlag
    , paths : Paths
    }


type alias Context =
    { siteInfo : Maybe SiteInfo
    , paths : Paths
    }


contextFlagtoContext : ContextFlag -> Context
contextFlagtoContext contextFlag =
    let
        maybeSiteInfo =
            contextFlag.siteInfo
                |> Maybe.map
                    (\siteInfo ->
                        { user = siteInfo.user
                        , userId = UserId siteInfo.userId
                        , robot = siteInfo.robot
                        , robotId = RobotId siteInfo.robotId
                        }
                    )
    in
    Context maybeSiteInfo contextFlag.paths



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
    , viewUser : String
    , editRobot : String
    , publish : String
    , assets : String
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
    { userId : UserId
    , published : Bool
    , lang : String
    }


objDetailsDecoder : Decoder RobotDetails
objDetailsDecoder =
    oneOf [ siteRobotDecoder, localRobotDecoder ]


siteRobotDecoder : Decoder RobotDetails
siteRobotDecoder =
    succeed SiteRobot
        |> required "userId" (id |> map UserId)
        |> required "published" bool
        |> required "lang" string
        |> map Site


localRobotDecoder : Decoder RobotDetails
localRobotDecoder =
    succeed Local



-- ROUTES


getUserRobots : Context -> String -> Request (List Robot)
getUserRobots context user =
    Get ( context.paths.getUserRobots, [ user ], list robotDecoder )


builtinUsername =
    "builtin"


getBuiltinRobots : Context -> Request (List Robot)
getBuiltinRobots context =
    getUserRobots context builtinUsername


getRobotCode : Context -> RobotId -> Request String
getRobotCode context robotId =
    Get ( context.paths.getRobotCode, [ String.fromInt (unwrapRobotId robotId) ], string )


updateRobotCode : Context -> RobotId -> String -> Request ()
updateRobotCode context robotId code =
    Post ( context.paths.updateRobotCode, [ String.fromInt (unwrapRobotId robotId) ], succeed () )
        [ stringPart "code" code ]


urlForViewingRobot : Context -> RobotId -> String
urlForViewingRobot context robotId =
    generateUrl context.paths.viewRobot [ String.fromInt (unwrapRobotId robotId) ]


urlForViewingUser : Context -> String -> String
urlForViewingUser context user =
    generateUrl context.paths.viewUser [ user ]


urlForEditingRobot : Context -> RobotId -> String
urlForEditingRobot context robotId =
    generateUrl context.paths.editRobot [ String.fromInt (unwrapRobotId robotId) ]


urlForPublishing : Context -> String
urlForPublishing context =
    generateUrl context.paths.publish []


urlForAsset : Context -> String -> String
urlForAsset context asset =
    generateUrl context.paths.assets [ asset ]
