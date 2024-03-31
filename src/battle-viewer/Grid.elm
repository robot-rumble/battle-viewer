module Grid exposing (Data, Msg(..), view)

import Data
import Dict
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)


to_perc : Float -> String
to_perc float =
    String.fromFloat float ++ "%"


map_size =
    19


max_health =
    5



-- UPDATE


type Msg
    = UnitSelected Data.Id



-- VIEW


type alias Data =
    { data : Data.ProgressData
    , selectedId : Maybe Data.Id
    , maybeTeam : Maybe Data.Team
    , gameMode : Data.GameMode
    }


view : Maybe Data -> Html Msg
view maybeData =
    let
        gridTemplateRows =
            "repeat(" ++ String.fromInt map_size ++ ", 1fr)"

        gridTemplateColumns =
            "repeat(" ++ String.fromInt map_size ++ ", 1fr)"
    in
    div [ class "_renderer-wrapper" ]
        [ div
            [ class "_renderer"
            , style "grid-template-rows" gridTemplateRows
            , style "grid-template-columns" gridTemplateColumns
            ]
          <|
            List.append gameGrid
                (case maybeData of
                    Just { data, selectedId, maybeTeam, gameMode } ->
                        (case gameMode of
                            Data.Hill ->
                                hillDivs

                            _ ->
                                []
                        )
                            ++ gameObjs data selectedId maybeTeam

                    Nothing ->
                        []
                )
        ]


gameGrid : List (Html Msg)
gameGrid =
    List.append
        (List.range 1 map_size
            |> List.map
                (\y ->
                    div [ class "grid-row", style "grid-area" <| "1 / " ++ String.fromInt y ++ "/ end / auto" ] []
                )
        )
        (List.range 1 map_size
            |> List.map
                (\x ->
                    div [ class "grid-col", style "grid-area" <| String.fromInt x ++ "/ 1 / auto / end" ] []
                )
        )


hillCoords =
    [ ( 9, 9 ), ( 8, 9 ), ( 8, 8 ), ( 9, 8 ), ( 10, 8 ), ( 10, 9 ), ( 10, 10 ), ( 9, 10 ), ( 8, 10 ) ]


hillDivs =
    hillCoords
        |> List.map
            (\( x, y ) ->
                div
                    [ class "hill"
                    , style "grid-column" <| String.fromInt (x + 1)
                    , style "grid-row" <| String.fromInt (y + 1)
                    ]
                    []
            )


gameObjs : Data.ProgressData -> Maybe Data.Id -> Maybe Data.Team -> List (Html Msg)
gameObjs data selectedUnit maybeTeam =
    Dict.values data.state.objs
        |> List.map
            (\( basic, details ) ->
                let
                    ( x, y ) =
                        basic.coords
                in
                div
                    ([ class "obj"
                     , class basic.id
                     , style "grid-column" <| String.fromInt (x + 1)
                     , style "grid-row" <| String.fromInt (y + 1)
                     ]
                        ++ (case details of
                                Data.UnitDetails unit ->
                                    [ class "unit"
                                    , class <| "team-" ++ unit.team
                                    , onClick (UnitSelected basic.id)
                                    , class <|
                                        case selectedUnit of
                                            Just id ->
                                                if id == basic.id then
                                                    "selected"

                                                else
                                                    ""

                                            Nothing ->
                                                ""
                                    , class <|
                                        case Dict.get basic.id data.robotActions of
                                            Just (Err _) ->
                                                "errored"

                                            _ ->
                                                ""
                                    , class <|
                                        case maybeTeam |> Maybe.andThen (\team -> Dict.get team data.debugLocateQueries) of
                                            Just queries ->
                                                if List.member basic.id queries then
                                                    "located"

                                                else
                                                    ""

                                            Nothing ->
                                                ""
                                    ]

                                Data.TerrainDetails terrain ->
                                    [ class "terrain"
                                    , class <|
                                        "type-"
                                            ++ (case terrain.type_ of
                                                    Data.Wall ->
                                                        "wall"
                                               )
                                    ]
                           )
                    )
                    [ case details of
                        Data.UnitDetails unit ->
                            div
                                [ class "health-bar"
                                , style "opacity" <| String.fromFloat (toFloat unit.health / toFloat max_health)
                                ]
                                []

                        _ ->
                            div [] []
                    ]
            )
