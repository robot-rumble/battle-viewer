module Data exposing (..)

import Basics
import Dict exposing (Dict)
import Array exposing (Array)
import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (required, custom)
import Json.Encode as Encode

arrayAsTuple2 : Decoder a -> Decoder b -> Decoder ( a, b )
arrayAsTuple2 a b =
    index 0 a
        |> andThen
            (\aVal ->
                index 1 b
                    |> andThen (\bVal -> Json.Decode.succeed ( aVal, bVal ))
            )


stringAsUnion : List ( String, a ) -> Decoder String -> Decoder a
stringAsUnion mapping =
    let
        dict =
            Dict.fromList mapping
    in
    andThen
        (\str ->
            case Dict.get str dict of
                Just a ->
                    succeed a

                Nothing ->
                    fail ("Invalid type: " ++ str)
        )


unionDecoder : List ( String, a ) -> List ( String, String -> a ) -> Decoder a
unionDecoder plainMappings valueMappings =
    let
        decodePlain =
            string |> stringAsUnion plainMappings

        decodeWithValue =
            index 0 string |> stringAsUnion valueMappings |> andThen (\unionType -> map unionType <| index 1 string)
    in
    oneOf [ decodePlain, decodeWithValue ]


type alias Id =
    String


type alias Coords =
    ( Int, Int )


type alias Team =
    String



type alias Outcome =
    { winner : Maybe String
    }

decodeOutcome : Value -> Result Json.Decode.Error Outcome
decodeOutcome = decodeValue outcomeDecoder

outcomeDecoder : Decoder Outcome
outcomeDecoder =
    succeed Outcome
    |> required "winner" (nullable string)


type alias Error =
    { message : String
    , errorLoc : Maybe ErrorLoc
    }

type alias ErrorLoc =
    { line : Int
    , ch : Int
    , endline : Int
    , endch : Int
    }

decodeError : Value -> Result Json.Decode.Error Error
decodeError = decodeValue errorDecoder

errorDecoder : Decoder Error
errorDecoder =
        succeed Error
        |> required "message" string
        |> custom (field "errorLoc" (nullable errorLocDecoder))


errorLocDecoder : Decoder ErrorLoc
errorLocDecoder =
    succeed ErrorLoc
    |> required "line" int
    |> required "ch" int
    |> required "endline" int
    |> required "endch" int


decodeProgress : Value -> Result Json.Decode.Error Input
decodeProgress = decodeValue inputDecoder


nullableIntEncoder : Maybe Int -> Encode.Value
nullableIntEncoder val =
    case val of
        Just int -> Encode.int int
        Nothing -> Encode.null

errorLocEncoder : ErrorLoc -> Encode.Value
errorLocEncoder errorLoc =
    Encode.object
        [ ( "line", Encode.int errorLoc.line )
        , ( "ch", Encode.int errorLoc.ch )
        , ( "endline", Encode.int errorLoc.endline )
        , ( "endch", Encode.int errorLoc.endch )
        ]


type alias Input =
    { state: State
    }


inputDecoder : Decoder Input
inputDecoder =
    succeed Input
    |> required "state" stateDecoder


type alias State =
    { turn : Int
    , objs : Dict String Obj
    }


stateDecoder : Decoder State
stateDecoder =
    succeed State
    |> required "turn" int
    |> required "objs" (dict objDecoder)

type alias Obj = ( BasicObj, ObjDetails )

objDecoder : Decoder Obj
objDecoder =
    basicObjDecoder |> andThen (\basic_obj ->
        objDetailsDecoder |> andThen (\obj_details ->
            Json.Decode.succeed (basic_obj, obj_details)
        )
    )

type alias BasicObj =
    { coords : Coords
    , id : Id
    }

basicObjDecoder : Decoder BasicObj
basicObjDecoder =
    succeed BasicObj
        |> required "coords" (arrayAsTuple2 int int)
        |> required "id" string


type ObjDetails = UnitDetails Unit | TerrainDetails Terrain

objDetailsDecoder : Decoder ObjDetails
objDetailsDecoder =
    field "type" string
    |> andThen (\type_ ->
        case type_ of
            "Soldier" -> unitDecoder |> map UnitDetails
            "Wall" -> terrainDecoder |> map TerrainDetails
            _ -> fail ("Invalid type: " ++ type_)
        )

type alias Unit =
    { type_ : UnitType
    , health : Int
    , team : Team
    }

type UnitType
    = Soldier

unitDecoder : Decoder Unit
unitDecoder =
    succeed Unit
        |> required "type" (string |> stringAsUnion [ ( "Soldier", Soldier ) ])
        |> required "health" int
        |> required "team" string


type alias Terrain =
    { type_ : TerrainType
    }

type TerrainType
    = Wall

terrainDecoder : Decoder Terrain
terrainDecoder =
    succeed Terrain
        |> required "type" (string |> stringAsUnion [ ( "Wall", Wall ) ])

