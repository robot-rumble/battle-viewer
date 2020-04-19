module Data exposing (..)

import Dict exposing (Dict)
import Json.Decode exposing (..)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as E



-- UTILS


arrayAsTuple2 : Decoder a -> Decoder b -> Decoder ( a, b )
arrayAsTuple2 a b =
    index 0 a
        |> andThen
            (\aVal ->
                index 1 b
                    |> andThen (\bVal -> Json.Decode.succeed ( aVal, bVal ))
            )


union : List ( String, a ) -> Decoder a
union mapping =
    string
        |> andThen
            (\str ->
                Dict.get str (Dict.fromList mapping)
                    |> Maybe.map (\a -> succeed a)
                    |> Maybe.withDefault (fail ("Invalid type: " ++ str))
            )


result : Decoder b -> Decoder a -> Decoder (Result b a)
result err ok =
    oneOf
        [ field "Ok" ok
            |> andThen (\okData -> succeed (Ok okData))
        , field "Err" err
            |> andThen (\errData -> succeed (Err errData))
        ]


encodeNull : (a -> E.Value) -> Maybe a -> E.Value
encodeNull encode val =
    case val of
        Just a ->
            encode a

        Nothing ->
            E.null



-- OUTCOME/PROGRESS DATA


type alias Id =
    String


type alias Coords =
    ( Int, Int )


type alias Team =
    String


type alias OutcomeData =
    { winner : Maybe Team
    , errors : Dict Team OutcomeError
    }


decodeOutcomeData : Value -> Result Json.Decode.Error OutcomeData
decodeOutcomeData =
    decodeValue outcomeDataDecoder


outcomeDataDecoder : Decoder OutcomeData
outcomeDataDecoder =
    succeed OutcomeData
        |> required "winner" (nullable string)
        |> required "errors" (dict outcomeErrorDecoder)


type OutcomeError
    = InternalError
    | NoData
    | InitError Error
    | NoInitError
    | DataError String
    | IOError String


outcomeErrorToString : OutcomeError -> String
outcomeErrorToString outcomeError =
    case outcomeError of
        InitError error ->
            error.message

        _ ->
            "Internal error!"


outcomeErrorDecoder : Decoder OutcomeError
outcomeErrorDecoder =
    oneOf
        [ field "InitError" errorDecoder |> map InitError
        , field "DataError" string |> map DataError
        , field "IOError" string |> map IOError
        ]


type alias Error =
    { message : String
    , loc : ErrorLoc
    }


errorDecoder : Decoder Error
errorDecoder =
    succeed Error
        |> required "message" string
        |> required "loc" errorLocDecoder


type alias Range =
    ( Int, Maybe Int )


type alias ErrorLoc =
    { start : Range
    , end : Maybe Range
    }


errorLocDecoder : Decoder ErrorLoc
errorLocDecoder =
    succeed ErrorLoc
        |> required "start" (arrayAsTuple2 int (nullable int))
        |> required "end" (nullable (arrayAsTuple2 int (nullable int)))


errorLocEncoder : ErrorLoc -> E.Value
errorLocEncoder errorLoc =
    let
        ( line, ch ) =
            errorLoc.start

        ( endline, endch ) =
            case errorLoc.end of
                Just ( a, b ) ->
                    ( Just a, b )

                Nothing ->
                    ( Nothing, Nothing )
    in
    E.object
        [ ( "line", E.int line )
        , ( "ch", encodeNull E.int ch )
        , ( "endline", encodeNull E.int endline )
        , ( "endch", encodeNull E.int endch )
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
    { action : Result String Action
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
        |> required "type" (union [ ( "Move", Move ), ( "Attack", Attack ) ])
        |> required "direction" (union [ ( "North", North ), ( "South", South ), ( "East", East ), ( "West", West ) ])


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
        |> required "type" (union [ ( "Soldier", Soldier ) ])
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
        |> required "type" (union [ ( "Wall", Wall ) ])
