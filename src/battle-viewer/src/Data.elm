module Data exposing (..)

import Dict exposing (Dict)
import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (custom, required)
import Json.Encode as Encode



-- UTILS


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


result : Decoder b -> Decoder a -> Decoder (Result b a)
result err ok =
    oneOf
        [ field "Ok" ok
            |> andThen (\okData -> succeed (Ok okData))
        , field "Err" err
            |> andThen (\errData -> succeed (Err errData))
        ]



-- OUTCOME/PROGRESS DATA


type alias Id =
    String


type alias Coords =
    ( Int, Int )


type alias Team =
    String


type alias E =
    String


type alias OutcomeData =
    { winner : Maybe Team
    , errors : Dict Team E
    }


decodeOutcomeData : Value -> Result Json.Decode.Error OutcomeData
decodeOutcomeData =
    decodeValue outcomeDataDecoder


outcomeDataDecoder : Decoder OutcomeData
outcomeDataDecoder =
    succeed OutcomeData
        |> required "winner" (nullable string)
        |> required "errors" (dict string)


type alias Error =
    { message : String
    , errorLoc : Maybe ErrorLoc
    }


errorDecoder : Decoder Error
errorDecoder =
    succeed Error
        |> required "message" string
        |> custom (field "errorLoc" (nullable errorLocDecoder))


type alias ErrorLoc =
    { line : Int
    , ch : Int
    , endline : Int
    , endch : Int
    }


errorLocDecoder : Decoder ErrorLoc
errorLocDecoder =
    succeed ErrorLoc
        |> required "line" int
        |> required "ch" int
        |> required "endline" int
        |> required "endch" int


errorLocEncoder : ErrorLoc -> Encode.Value
errorLocEncoder errorLoc =
    Encode.object
        [ ( "line", Encode.int errorLoc.line )
        , ( "ch", Encode.int errorLoc.ch )
        , ( "endline", Encode.int errorLoc.endline )
        , ( "endch", Encode.int errorLoc.endch )
        ]


type alias RobotOutputs =
    Dict Id RobotOutput


type alias ProgressData =
    { state : TurnState
    , logs : Dict Team (List String)
    , robotOutputs : RobotOutputs
    }


decodeProgressData : Value -> Result Json.Decode.Error ProgressData
decodeProgressData =
    decodeValue progressDataDecoder


progressDataDecoder : Decoder ProgressData
progressDataDecoder =
    succeed ProgressData
        |> required "state" stateDecoder
        |> required "logs" (dict (list string))
        |> required "robot_outputs" (dict robotOutputDecoder)


type alias RobotOutput =
    { action : Result E Action
    , debugTable : Dict String String
    }


robotOutputDecoder : Decoder RobotOutput
robotOutputDecoder =
    succeed RobotOutput
        |> required "action" (result string actionDecoder)
        |> required "debug_table" (dict string)


type ActionType
    = Move
    | Attack


type Direction
    = North
    | South
    | East
    | West


type alias Action =
    { type_ : ActionType
    , direction : Direction
    }


actionDecoder : Decoder Action
actionDecoder =
    succeed Action
        |> required "type" (string |> stringAsUnion [ ( "Move", Move ), ( "Attack", Attack ) ])
        |> required "direction" (string |> stringAsUnion [ ( "North", North ), ( "South", South ), ( "East", East ), ( "West", West ) ])


type alias TurnState =
    { turn : Int
    , objs : Dict Id Obj
    }


stateDecoder : Decoder TurnState
stateDecoder =
    succeed TurnState
        |> required "turn" int
        |> required "objs" (dict objDecoder)



-- OBJ


type alias Obj =
    ( BasicObj, ObjDetails )


objDecoder : Decoder Obj
objDecoder =
    basicObjDecoder
        |> andThen
            (\basic_obj ->
                objDetailsDecoder
                    |> andThen
                        (\obj_details ->
                            Json.Decode.succeed ( basic_obj, obj_details )
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


type ObjDetails
    = UnitDetails Unit
    | TerrainDetails Terrain


objDetailsDecoder : Decoder ObjDetails
objDetailsDecoder =
    field "type" string
        |> andThen
            (\type_ ->
                case type_ of
                    "Soldier" ->
                        unitDecoder |> map UnitDetails

                    "Wall" ->
                        terrainDecoder |> map TerrainDetails

                    _ ->
                        fail ("Invalid type: " ++ type_)
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
