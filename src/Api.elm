module Api exposing (Context, Id, Paths, Result, Robot, getRobotCode, getUserRobots, makeRequest)

import Http
import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as Encode
import Url.Builder exposing (crossOrigin)



-- CTX


type alias Context =
    { user : String
    , robot : String
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
    }


type Request val
    = Get (Endpoint val)
    | Post (Endpoint val) Encode.Value


makeRequest : (Result val -> msg) -> Request val -> Cmd msg
makeRequest msg request =
    case request of
        Get ( basePath, pathSegments, decoder ) ->
            Http.get
                { url = crossOrigin basePath pathSegments []
                , expect = Http.expectJson msg decoder
                }

        Post ( basePath, pathSegments, decoder ) body ->
            Http.post
                { url = crossOrigin basePath pathSegments []
                , expect = Http.expectJson msg decoder
                , body = Http.jsonBody body
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


getUserRobots paths user =
    Get ( paths.getUserRobots, [ user ], list robotDecoder )


getRobotCode paths robot =
    Get ( paths.getRobotCode, [ String.fromInt robot ], string )
