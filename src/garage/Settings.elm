module Settings exposing (Model, Msg, decodeSettings, default, encodeSettings, update, view)

import Data
import Dict
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as D
import Json.Decode.Pipeline as Pipeline
import Json.Encode as E


type KeyMap
    = Default
    | Sublime
    | Emacs
    | Vim


encodeKeyMap keyMap =
    case keyMap of
        Default ->
            "Default"

        Sublime ->
            "Sublime"

        Emacs ->
            "Emacs"

        Vim ->
            "Vim"


keyMapDict =
    [ ( "Default", Default ), ( "Sublime", Sublime ), ( "Emacs", Emacs ), ( "Vim", Vim ) ]


keyMapDecoder =
    Data.union keyMapDict


type Theme
    = Light
    | Dark


encodeTheme theme =
    case theme of
        Light ->
            "Light"

        Dark ->
            "Dark"


themeDict =
    [ ( "Light", Light ), ( "Dark", Dark ) ]


themeDecoder =
    Data.union themeDict


type alias Settings =
    { theme : Theme
    , keyMap : KeyMap
    }


default =
    Settings Light Default


settingsDecoder =
    D.succeed Settings
        |> Pipeline.required "theme" themeDecoder
        |> Pipeline.required "keyMap" keyMapDecoder


decodeSettings =
    D.decodeValue settingsDecoder


encodeSettings settings =
    E.object
        [ ( "keyMap"
          , E.string <| encodeKeyMap settings.keyMap
          )
        , ( "theme"
          , E.string <| encodeTheme settings.theme
          )
        ]


type alias Model =
    Settings


type Msg
    = SetKeymap String
    | SetTheme String


update : Msg -> Model -> Model
update msg model =
    case msg of
        SetKeymap keymap ->
            { model | keyMap = D.decodeValue keyMapDecoder (E.string keymap) |> Result.withDefault Default }

        SetTheme theme ->
            { model | theme = D.decodeValue themeDecoder (E.string theme) |> Result.withDefault Light }


toOption : String -> Bool -> Html Msg
toOption val sel =
    option [ value val, selected sel ] [ text val ]


createSelect : (String -> Msg) -> String -> List ( String, a ) -> Html Msg
createSelect msg selected options =
    select [ onInput msg ]
        (Dict.fromList options
            |> Dict.keys
            |> List.map (\key -> toOption key (key == selected))
        )


view : Model -> Html Msg
view model =
    div [ class "m-3" ]
        [ div [ class "d-flex" ]
            [ div [ class "mr-3" ]
                [ p [] [ text "keymap" ]
                , createSelect SetKeymap (encodeKeyMap model.keyMap) keyMapDict
                ]
            , div []
                [ p [] [ text "theme" ]
                , createSelect SetTheme (encodeTheme model.theme) themeDict
                ]
            ]
        , p [ class "mt-3" ] [ text "You'll need to reload the page for the changes to take effect." ]
        ]
