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


coordsToString : Coords -> String
coordsToString ( x, y ) =
    "(" ++ String.fromInt x ++ ", " ++ String.fromInt y ++ ")"


type alias Team =
    String


type alias OutcomeErrors =
    Dict Team OutcomeError


type alias OutcomeData =
    { winner : Maybe Team
    , errors : OutcomeErrors
    }


decodeOutcomeData : Value -> Result Json.Decode.Error OutcomeData
decodeOutcomeData =
    decodeValue outcomeDataDecoder


outcomeDataDecoder : Decoder OutcomeData
outcomeDataDecoder =
    succeed OutcomeData
        |> required "winner" (nullable string)
        |> required "errors" (dict outcomeErrorDecoder)



-- Technically the output generated by logic is always FullOutcomeData,
-- but we don't need to parse the `turns` field in the garage because
-- we get the turn state as-it-happens through the callback subscription


type alias FullOutcomeData =
    { winner : Maybe Team
    , errors : OutcomeErrors
    , turns : List ProgressData
    }


decodeFullOutcomeData : Value -> Result Json.Decode.Error FullOutcomeData
decodeFullOutcomeData =
    decodeValue fullOutcomeDataDecoder


fullOutcomeDataDecoder : Decoder FullOutcomeData
fullOutcomeDataDecoder =
    succeed FullOutcomeData
        |> required "winner" (nullable string)
        |> required "errors" (dict outcomeErrorDecoder)
        |> required "turns" (list progressDataDecoder)


type Error
    = OutcomeErrorType OutcomeError
    | RobotErrorType RobotError


type OutcomeError
    = InternalError
    | NoData
    | InitError ErrorDetails
    | NoInitError
    | DataError String
    | IOError String
    | Timeout


outcomeErrorDecoder : Decoder OutcomeError
outcomeErrorDecoder =
    oneOf
        [ string
            |> andThen
                (\str ->
                    case str of
                        "InternalError" ->
                            succeed InternalError

                        "NoInitError" ->
                            succeed NoInitError

                        "NoData" ->
                            succeed NoData

                        "Timeout" ->
                            succeed Timeout

                        _ ->
                            succeed InternalError
                )
        , field "InitError" errorDecoder |> map InitError
        , field "DataError" string |> map DataError
        , field "IO" string |> map IOError
        ]


type alias ErrorDetails =
    { summary : String
    , details : Maybe String
    , loc : Maybe ErrorLoc
    }


errorDecoder : Decoder ErrorDetails
errorDecoder =
    succeed ErrorDetails
        |> required "summary" string
        |> required "details" (nullable string)
        |> required "loc" (nullable errorLocDecoder)


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


type alias DebugTable =
    Dict String String


type alias ActionResult =
    Result RobotError (Maybe Action)


type alias ProgressData =
    { state : TurnState
    , logs : Dict Team (List String)
    , robotActions : Dict Id ActionResult
    , debugTables : Dict Id DebugTable
    , debugInspections : Dict Team (List Id)
    }


decodeProgressData : Value -> Result Json.Decode.Error ProgressData
decodeProgressData =
    decodeValue progressDataDecoder


progressDataDecoder : Decoder ProgressData
progressDataDecoder =
    succeed ProgressData
        |> required "state" stateDecoder
        |> required "logs" (dict (list string))
        |> required "robot_actions" (dict (result robotErrorDecoder (nullable actionDecoder)))
        |> required "debug_tables" (dict (dict string))
        |> required "debug_inspections" (dict (list string))


type RobotError
    = RuntimeError ErrorDetails
    | InvalidAction String


robotErrorDecoder : Decoder RobotError
robotErrorDecoder =
    oneOf
        [ field "RuntimeError" errorDecoder |> map RuntimeError
        , field "InvalidAction" string |> map InvalidAction
        ]


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


actionToString : Action -> String
actionToString action =
    let
        verb =
            case action.type_ of
                Move ->
                    "Move"

                Attack ->
                    "Attack"

        direction =
            case action.direction of
                North ->
                    "North"

                South ->
                    "South"

                West ->
                    "West"

                East ->
                    "East"
    in
    verb ++ " " ++ direction


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
