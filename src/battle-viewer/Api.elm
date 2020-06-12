module Api exposing (Context, Id, Paths, Result, Robot, getRobotCode, getUserRobots, makeRequest, updateRobotCode)

import Http exposing (Part, stringPart)
import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as Encode
import Url.Builder exposing (crossOrigin)



-- CTX


type alias Context =
    { user : String
    , robot : String
    , robotId : Int
    , paths : Paths
    }



-- HTTP


type alias Error =
    Http.Error


type alias Result val =
    Result.Result Error val


type alias Endpoint val =
    ( String, List String, Decoder val )


type alias Paths =
    { getUserRobots : String
    , getRobotCode : String
    , updateRobotCode : String
    }


type Request val
    = Get (Endpoint val)
    | Post (Endpoint val) (List Part)


makeRequest : (Result val -> msg) -> Request val -> Cmd msg
makeRequest msg request =
    case request of
        Get ( basePath, pathSegments, decoder ) ->
            Http.get
                { url = crossOrigin basePath pathSegments []
                , expect = Http.expectJson msg decoder
                }

        Post ( basePath, pathSegments, decoder ) parts ->
            Http.post
                { url = crossOrigin basePath pathSegments []
                , expect = Http.expectJson msg decoder
                , body = Http.multipartBody parts
                }



-- ROBOT


type alias Id =
    Int


type alias Robot =
    { id : Id
    , name : String
    , rating : Int
    , lang : String
    }


robotDecoder =
    succeed Robot
        |> required "id" int
        |> required "name" string
        |> required "rating" int
        |> required "lang" string


getUserRobots context user =
    Get ( context.paths.getUserRobots, [ user ], list robotDecoder )


getRobotCode context robot =
    Get ( context.paths.getRobotCode, [ String.fromInt robot ], string )


updateRobotCode context code =
    Post ( context.paths.updateRobotCode, [ String.fromInt context.robotId ], succeed () )
        [ stringPart "code" code ]
