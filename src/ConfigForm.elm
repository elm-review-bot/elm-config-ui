module ConfigForm exposing
    ( ConfigForm, init, InitOptions, Defaults, Logic
    , Field
    , int, float, string, color
    , Msg
    , update, updateFromJson
    , encode, encodeForm
    , view
    )

{-|


# Main stuff

@docs ConfigForm, init, InitOptions, Defaults, Logic


# Field

@docs Field


# Field Types

@docs IntField, FloatField, StringField, ColorField


# Field functions

@docs int, float, string, color


# Msg

@docs Msg


# Update

@docs update, updateFromJson


# Encoding

@docs encode, encodeForm


# View

@docs view

-}

import Color exposing (Color)
import ColorPicker
import Element as E exposing (Element)
import Element.Background as EBackground
import Element.Border as EBorder
import Element.Events as EEvents
import Element.Font as EFont
import Element.Input as EInput
import Html exposing (Html)
import Html.Attributes
import Html.Events
import Json.Decode as JD
import Json.Decode.Pipeline as JDP
import Json.Encode as JE
import OrderedDict exposing (OrderedDict)



{- ConfigForm is persisted! -}


type alias ConfigForm config =
    { file : config -- unused for now
    , configForm : OrderedDict String Field
    }


type Field
    = StringField StringFieldData
    | IntField IntFieldData
    | FloatField FloatFieldData
    | ColorField ColorFieldData


type alias IntFieldData =
    { val : Int
    , isChanging : Bool
    }


type alias FloatFieldData =
    { val : Float
    , isChanging : Bool
    }


type alias StringFieldData =
    { val : String
    }


type alias ColorFieldData =
    { val : Color
    , meta : ColorFieldMeta
    }


type ColorFieldMeta
    = ColorFieldMeta
        { state : ColorPicker.State
        , isOpen : Bool
        }


type alias Flags =
    { configJson : JE.Value -- currently unused
    , configFormJson : JE.Value
    , defaults : Defaults
    }


type alias Defaults =
    { int : Int
    , float : Float
    , string : String
    , color : Color
    }


type alias InitOptions config =
    { configJson : JE.Value
    , configFormJson : JE.Value
    , logics : List (Logic config)
    , emptyConfig : config
    }


init : InitOptions config -> ( config, ConfigForm config )
init options =
    let
        config =
            configDecoder
                options.logics
                options.emptyConfig
                options.configJson

        configForm =
            configFormDecoder
                options.logics
                config
                options.configFormJson
    in
    ( config, configForm )



{- Logic stuff. Never persist Logic in your model! -}


type alias Logic config =
    { fieldName : String
    , label : String
    , kind : LogicKind config
    }


type LogicKind config
    = StringLogic (config -> String) (String -> config -> config)
    | IntLogic (config -> Int) (Int -> config -> config)
    | FloatLogic (config -> Float) (Float -> config -> config)
    | ColorLogic (config -> Color) (Color -> config -> config)


int : String -> String -> (config -> Int) -> (Int -> config -> config) -> Logic config
int fieldName label getter setter =
    { fieldName = fieldName
    , label = label
    , kind = IntLogic getter setter
    }


float : String -> String -> (config -> Float) -> (Float -> config -> config) -> Logic config
float fieldName label getter setter =
    { fieldName = fieldName
    , label = label
    , kind = FloatLogic getter setter
    }


string : String -> String -> (config -> String) -> (String -> config -> config) -> Logic config
string fieldName label getter setter =
    { fieldName = fieldName
    , label = label
    , kind = StringLogic getter setter
    }


color : String -> String -> (config -> Color) -> (Color -> config -> config) -> Logic config
color fieldName label getter setter =
    { fieldName = fieldName
    , label = label
    , kind = ColorLogic getter setter
    }


view : config -> Html (Msg config)
view config =
    Html.text "CONFIG GO HERE"


type Msg config
    = ChangedConfig (config -> config)
    | ClickedPointerLockLabel (config -> config)
    | FromPort JE.Value


encode : List (Logic config) -> config -> JE.Value
encode logics config =
    --  FIXME
    JE.null


encodeForm : List (Logic config) -> ConfigForm config -> JE.Value
encodeForm logics config =
    --  FIXME
    JE.null


update : config -> ConfigForm config -> Msg config -> ( config, ConfigForm config, Maybe JE.Value )
update config configForm msg =
    -- FIXME
    ( config, configForm, Nothing )


updateFromJson : config -> ConfigForm config -> JE.Value -> ( config, ConfigForm config, Maybe JE.Value )
updateFromJson config configForm json =
    -- FIXME
    ( config, configForm, Nothing )


configDecoder : List (Logic config) -> config -> JE.Value -> config
configDecoder logics emptyConfig configJson =
    emptyConfig


configFormDecoder : List (Logic config) -> config -> JE.Value -> ConfigForm config
configFormDecoder logics config configFormJson =
    { file = config

    -- TODO
    , configForm = OrderedDict.empty
    }



-- JSON encode/decoder stuff
--------------
{--

type FieldData config
    = String (config -> StringField) (StringField -> config -> config)
    | Int (config -> IntField) (IntField -> config -> config)
    | Float (config -> FloatField) (FloatField -> config -> config)
    | Color (config -> ColorField) (ColorField -> config -> config)


type Msg config
    = ChangedConfig (config -> config)
    | ClickedPointerLockLabel (config -> config)
    | FromPort JE.Value


portMsgFromJson : JE.Value -> Msg config
portMsgFromJson json =
    FromPort json


type alias ConfigFormData config =
    ( String, String, FieldData config )


type PortMsg
    = MouseMove Int
    | MouseUp


portDecoder : JD.Decoder PortMsg
portDecoder =
    JD.field "id" JD.string
        |> JD.andThen
            (\id ->
                case id of
                    "MOUSE_MOVE" ->
                        JD.field "x" JD.int
                            |> JD.map MouseMove

                    "MOUSE_UP" ->
                        JD.succeed MouseUp

                    _ ->
                        JD.fail ("Could not decode ConfigForm port msg id: " ++ id)
            )


update : List (ConfigFormData config) -> Msg config -> config -> ( config, Maybe JE.Value )
update rows msg config =
    case msg of
        ChangedConfig updater ->
            ( updater config, Nothing )

        ClickedPointerLockLabel updater ->
            ( updater config, Just (JE.string "LOCK_POINTER") )

        FromPort json ->
            case JD.decodeValue portDecoder json of
                Ok portMsg ->
                    case portMsg of
                        MouseMove num ->
                            ( rows
                                |> List.foldl
                                    (\(( _, _, field ) as row) c ->
                                        case field of
                                            Int getter setter ->
                                                let
                                                    oldField =
                                                        getter config

                                                    newField =
                                                        if oldField.isChanging then
                                                            { oldField
                                                                | val =
                                                                    oldField.val + num
                                                            }

                                                        else
                                                            oldField
                                                in
                                                setter newField c

                                            Float getter setter ->
                                                let
                                                    oldField =
                                                        getter config

                                                    newField =
                                                        if oldField.isChanging then
                                                            { oldField
                                                                | val =
                                                                    oldField.val + toFloat num
                                                            }

                                                        else
                                                            oldField
                                                in
                                                setter newField c

                                            String getter setter ->
                                                c

                                            Color getter setter ->
                                                c
                                    )
                                    config
                            , Nothing
                            )

                        MouseUp ->
                            ( rows
                                |> List.foldl
                                    (\(( _, _, field ) as row) c ->
                                        case field of
                                            Int getter setter ->
                                                let
                                                    oldField =
                                                        getter config

                                                    newField =
                                                        { oldField
                                                            | isChanging =
                                                                False
                                                        }
                                                in
                                                setter newField c

                                            Float getter setter ->
                                                let
                                                    oldField =
                                                        getter config

                                                    newField =
                                                        { oldField
                                                            | isChanging =
                                                                False
                                                        }
                                                in
                                                setter newField c

                                            String getter setter ->
                                                c

                                            Color getter setter ->
                                                c
                                    )
                                    config
                            , Nothing
                            )

                Err err ->
                    let
                        _ =
                            Debug.log
                                "Could not decode incoming config port msg: "
                                (JD.errorToString err)
                    in
                    ( config, Nothing )



-- VIEW


type alias ViewOptions =
    { tableBgColor : Color
    , tableSpacing : Int
    , tablePadding : Int
    , tableBorderWidth : Int
    , tableBorderColor : Color
    , labelHighlightBgColor : Color
    }


viewOptions : ViewOptions
viewOptions =
    { tableBgColor = Color.rgba 1 1 1 0
    , tableSpacing = 5
    , tablePadding = 5
    , tableBorderWidth = 1
    , tableBorderColor = Color.rgb 0 0 0
    , labelHighlightBgColor = Color.rgba 0.2 0.2 1 0.3
    }


withTableBgColor : Color -> ViewOptions -> ViewOptions
withTableBgColor val options =
    { options | tableBgColor = val }


withTableSpacing : Int -> ViewOptions -> ViewOptions
withTableSpacing val options =
    { options | tableSpacing = val }


withTablePadding : Int -> ViewOptions -> ViewOptions
withTablePadding val options =
    { options | tablePadding = val }


withTableBorderWidth : Int -> ViewOptions -> ViewOptions
withTableBorderWidth val options =
    { options | tableBorderWidth = val }


withTableBorderColor : Color -> ViewOptions -> ViewOptions
withTableBorderColor val options =
    { options | tableBorderColor = val }


withLabelHighlightBgColor : Color -> ViewOptions -> ViewOptions
withLabelHighlightBgColor val options =
    { options | labelHighlightBgColor = val }


view : config -> List ( String, FieldData config ) -> ViewOptions -> Element (Msg config)
view config formList options =
    E.indexedTable
        [ EBackground.color (colorForE options.tableBgColor)
        , E.spacing options.tableSpacing
        , E.padding options.tablePadding
        , EBorder.width options.tableBorderWidth
        , EBorder.color (colorForE options.tableBorderColor)
        ]
        { data = formList
        , columns =
            [ { header = E.none
              , width = E.fill
              , view =
                    \i ( label, val ) ->
                        let
                            resizeAttrs getter setter =
                                let
                                    field =
                                        getter config
                                in
                                [ EEvents.onMouseDown (ClickedPointerLockLabel (setter { field | isChanging = True }))
                                , E.htmlAttribute (Html.Attributes.style "cursor" "ew-resize")
                                ]

                            defaultAttrs getter setter =
                                [ E.mouseOver
                                    [ EBackground.color
                                        (colorForE options.labelHighlightBgColor)
                                    ]
                                ]

                            attrs =
                                case val of
                                    String getter setter ->
                                        defaultAttrs getter setter

                                    Int getter setter ->
                                        defaultAttrs getter setter
                                            ++ resizeAttrs getter setter

                                    Float getter setter ->
                                        defaultAttrs getter setter
                                            ++ resizeAttrs getter setter

                                    Color getter setter ->
                                        defaultAttrs getter setter
                        in
                        E.el
                            (attrs
                                ++ [ E.width E.fill
                                   , E.height E.fill
                                   ]
                            )
                            (E.el
                                [ E.centerY ]
                                (E.text label)
                            )
              }
            , { header = E.none
              , width = E.fill
              , view = viewChanger config
              }
            ]
        }


viewChanger : config -> Int -> ( String, FieldData config ) -> Element (Msg config)
viewChanger config index ( label, val ) =
    let
        defaultAttrs =
            [ Html.Attributes.tabindex (1 + index) |> E.htmlAttribute
            ]

        incrementalAttrs field setter =
            [ Html.Events.on "keydown"
                (JD.map
                    (\i ->
                        let
                            amt =
                                case i of
                                    38 ->
                                        1

                                    40 ->
                                        -1

                                    _ ->
                                        0
                        in
                        ChangedConfig
                            (setter { field | val = field.val + amt })
                    )
                    Html.Events.keyCode
                )
                |> E.htmlAttribute
            ]
    in
    case val of
        String getter setter ->
            let
                field =
                    getter config
            in
            textInputHelper
                { label = label
                , valStr = (getter config).val
                , attrs = defaultAttrs
                , setterMsg = \newStr -> ChangedConfig (setter { field | val = newStr })
                }

        Int getter setter ->
            let
                field =
                    getter config
            in
            textInputHelper
                { label = label
                , valStr = String.fromInt field.val
                , attrs = defaultAttrs ++ incrementalAttrs field setter
                , setterMsg =
                    \newStr ->
                        case String.toInt newStr of
                            Just newNum ->
                                ChangedConfig (setter { field | val = newNum })

                            Nothing ->
                                ChangedConfig identity
                }

        Float getter setter ->
            let
                field =
                    getter config
            in
            textInputHelper
                { label = label
                , valStr = String.fromFloat (getter config).val
                , attrs = defaultAttrs ++ incrementalAttrs field setter
                , setterMsg =
                    \newStr ->
                        case String.toFloat newStr of
                            Just newNum ->
                                ChangedConfig (setter { field | val = newNum })

                            Nothing ->
                                ChangedConfig identity
                }

        Color getter setter ->
            let
                field =
                    getter config

                meta =
                    case (getter config).meta of
                        ColorFieldMeta m ->
                            m
            in
            if meta.isOpen then
                ColorPicker.view
                    field.val
                    meta.state
                    |> E.html
                    |> E.map
                        (\pickerMsg ->
                            let
                                ( newPickerState, newColor ) =
                                    ColorPicker.update
                                        pickerMsg
                                        field.val
                                        meta.state
                            in
                            ChangedConfig <|
                                setter
                                    { field
                                        | val = newColor |> Maybe.withDefault field.val
                                        , meta =
                                            ColorFieldMeta
                                                { state = newPickerState
                                                , isOpen = meta.isOpen
                                                }
                                    }
                        )

            else
                EInput.text
                    (defaultAttrs
                        ++ [ EBackground.color (colorForE field.val)
                           , EEvents.onMouseDown
                                (ChangedConfig <|
                                    setter
                                        { field
                                            | val = field.val
                                            , meta =
                                                ColorFieldMeta
                                                    { state = meta.state
                                                    , isOpen = True
                                                    }
                                        }
                                )
                           ]
                    )
                    { label = EInput.labelHidden label
                    , text = ""
                    , onChange = always <| ChangedConfig identity
                    , placeholder = Nothing
                    }


textInputHelper :
    { label : String
    , valStr : String
    , attrs : List (E.Attribute (Msg config))
    , setterMsg : String -> Msg config
    }
    -> Element (Msg config)
textInputHelper { label, valStr, attrs, setterMsg } =
    EInput.text attrs
        { label = EInput.labelHidden label
        , text = valStr
        , onChange = setterMsg
        , placeholder = Nothing
        }


colorForE : Color -> E.Color
colorForE col =
    col
        |> Color.toRgba
        |> (\{ red, green, blue, alpha } ->
                E.rgba red green blue alpha
           )



-- JSON


type alias EncodeOptions =
    { withMeta : Bool
    }


encode : List ( String, String, FieldData config ) -> config -> JE.Value
encode list config =
    list
        |> List.map
            (\( key, _, fieldData ) ->
                ( key
                , case fieldData of
                    Int getter _ ->
                        JE.int (getter config).val

                    Float getter _ ->
                        JE.float (getter config).val

                    String getter _ ->
                        JE.string (getter config).val

                    Color getter _ ->
                        (getter config).val
                            |> Color.toRgba
                            |> (\{ red, green, blue, alpha } ->
                                    JE.object
                                        [ ( "r", JE.float red )
                                        , ( "g", JE.float green )
                                        , ( "b", JE.float blue )
                                        , ( "a", JE.float alpha )
                                        ]
                               )
                )
            )
        |> JE.object


type alias DecoderOptions =
    { defaultInt : Int
    , defaultFloat : Float
    , defaultString : String
    , defaultColor : Color
    }


int : DecoderOptions -> JE.Value -> String -> IntField
int options json key =
    let
        constructor num =
            { val = num
            , isChanging = False
            }
    in
    JD.decodeValue
        (JD.field key JD.int
            |> JD.map constructor
        )
        json
        |> Result.withDefault (constructor options.defaultInt)


float : DecoderOptions -> JE.Value -> String -> FloatField
float options json key =
    let
        constructor num =
            { val = num
            , isChanging = False
            }
    in
    JD.decodeValue
        (JD.field key JD.float
            |> JD.map constructor
        )
        json
        |> Result.withDefault (constructor options.defaultFloat)


string : DecoderOptions -> JE.Value -> String -> StringField
string options json key =
    let
        constructor str =
            { val = str
            }
    in
    JD.decodeValue
        (JD.field key JD.string
            |> JD.map
                (\str ->
                    constructor str
                )
        )
        json
        |> Result.withDefault (constructor options.defaultString)


colorValDecoder : JD.Decoder Color
colorValDecoder =
    JD.map4 Color.rgba
        (JD.field "r" JD.float)
        (JD.field "g" JD.float)
        (JD.field "b" JD.float)
        (JD.field "a" JD.float)


color : DecoderOptions -> JE.Value -> String -> ColorField
color options json key =
    let
        constructor col =
            { val = col
            , meta =
                ColorFieldMeta
                    { state = ColorPicker.empty
                    , isOpen = False
                    }
            }
    in
    JD.decodeValue
        (JD.field key colorValDecoder
            |> JD.map constructor
        )
        json
        |> Result.withDefault (constructor options.defaultColor)
        --}
