module ConfigForm exposing
    ( ColorField
    , EncodeOptions
    , FieldData(..)
    , FloatField
    , IntField
    , Msg
    , StringField
    , color
    , colorDecoder
    , encode
    , encodeColor
    , encodeFloat
    , encodeInt
    , encodeString
    , float
    , floatDecoder
    , int
    , intDecoder
    , string
    , stringDecoder
    , update
    , view
    )

import Color exposing (Color)
import ColorPicker
import Element as E exposing (Element)
import Element.Background as EBackground
import Element.Events as EEvents
import Element.Font as EFont
import Element.Input as EInput
import Json.Decode as JD
import Json.Decode.Pipeline as JDP
import Json.Encode as JE


type alias ConfigForm config =
    { file : JE.Value
    , config : config
    }


type alias Flags config =
    { file : JE.Value
    , localStorage : JE.Value
    , decoder : JD.Decoder config
    }


type alias IntField =
    { val : Int }


type alias FloatField =
    { val : Float }


type alias StringField =
    { val : String }


type alias ColorField =
    { val : Color
    , meta : ColorFieldMeta
    }


type ColorFieldMeta
    = ColorFieldMeta
        { state : ColorPicker.State
        , isOpen : Bool
        }


int : Int -> IntField
int num =
    { val = num }


float : Float -> FloatField
float num =
    { val = num }


string : String -> StringField
string str =
    { val = str }


color : Color -> ColorField
color col =
    { val = col
    , meta =
        ColorFieldMeta
            { state = ColorPicker.empty
            , isOpen = False
            }
    }


type FieldData config
    = String (config -> StringField) (StringField -> config -> config)
    | Int (config -> IntField) (IntField -> config -> config)
    | Float (config -> FloatField) (FloatField -> config -> config)
    | Color (config -> ColorField) (ColorField -> config -> config)


type Msg config
    = ChangeConfig (config -> config)


update : Msg config -> config -> config
update msg config =
    case msg of
        ChangeConfig updater ->
            updater config



-- VIEW


view : config -> List ( String, FieldData config ) -> Element (Msg config)
view config formList =
    E.table []
        { data = formList
        , columns =
            [ { header = E.none
              , width = E.fill
              , view =
                    \( label, val ) ->
                        E.text label
              }
            , { header = E.none
              , width = E.fill
              , view = viewChanger config
              }
            ]
        }


viewChanger : config -> ( String, FieldData config ) -> Element (Msg config)
viewChanger config ( label, val ) =
    case val of
        String getter setter ->
            textInputHelper
                { label = label
                , valStr = (getter config).val
                , setterMsg = \newStr -> ChangeConfig (setter (StringField newStr))
                }

        Int getter setter ->
            textInputHelper
                { label = label
                , valStr = String.fromInt (getter config).val
                , setterMsg =
                    \newStr ->
                        case String.toInt newStr of
                            Just newNum ->
                                ChangeConfig (setter (IntField newNum))

                            Nothing ->
                                ChangeConfig identity
                }

        Float getter setter ->
            textInputHelper
                { label = label
                , valStr = String.fromFloat (getter config).val
                , setterMsg =
                    \newStr ->
                        case String.toFloat newStr of
                            Just newNum ->
                                ChangeConfig (setter (FloatField newNum))

                            Nothing ->
                                ChangeConfig identity
                }

        Color getter setter ->
            let
                colorVal =
                    (getter config).val

                meta =
                    case (getter config).meta of
                        ColorFieldMeta m ->
                            m
            in
            if meta.isOpen then
                ColorPicker.view
                    colorVal
                    meta.state
                    |> E.html
                    |> E.map
                        (\pickerMsg ->
                            let
                                ( newPickerState, newColor ) =
                                    ColorPicker.update
                                        pickerMsg
                                        colorVal
                                        meta.state
                            in
                            ChangeConfig <|
                                setter
                                    { val = newColor |> Maybe.withDefault colorVal
                                    , meta =
                                        ColorFieldMeta
                                            { state = newPickerState
                                            , isOpen = meta.isOpen
                                            }
                                    }
                        )

            else
                EInput.text
                    [ EBackground.color (colorForE colorVal)
                    , EEvents.onMouseDown
                        (ChangeConfig <|
                            setter
                                { val = colorVal
                                , meta =
                                    ColorFieldMeta
                                        { state = meta.state
                                        , isOpen = True
                                        }
                                }
                        )
                    ]
                    { label = EInput.labelHidden label
                    , text = ""
                    , onChange = always <| ChangeConfig identity
                    , placeholder = Nothing
                    }


textInputHelper : { label : String, valStr : String, setterMsg : String -> Msg config } -> Element (Msg config)
textInputHelper { label, valStr, setterMsg } =
    EInput.text []
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


encode : EncodeOptions -> List ( String, EncodeOptions -> JE.Value ) -> JE.Value
encode options list =
    list
        |> List.map
            (Tuple.mapSecond
                (\partiallyAppliedEncode ->
                    partiallyAppliedEncode options
                )
            )
        |> JE.object


encodeInt : IntField -> EncodeOptions -> JE.Value
encodeInt field options =
    JE.int field.val


encodeFloat : FloatField -> EncodeOptions -> JE.Value
encodeFloat field options =
    JE.float field.val


encodeString : StringField -> EncodeOptions -> JE.Value
encodeString field options =
    JE.string field.val


encodeColor : ColorField -> EncodeOptions -> JE.Value
encodeColor field options =
    field.val
        |> Color.toRgba
        |> (\{ red, green, blue, alpha } ->
                JE.object
                    [ ( "r", JE.float red )
                    , ( "g", JE.float green )
                    , ( "b", JE.float blue )
                    , ( "a", JE.float alpha )
                    ]
           )


type alias DecoderOptions =
    { defaultInt : Int
    , defaultFloat : Float
    , defaultString : String
    , defaultColor : Color
    }


intDecoder : DecoderOptions -> JE.Value -> String -> IntField
intDecoder options json key =
    JD.decodeValue
        (JD.field key JD.int
            |> JD.map
                (\num ->
                    { val = num }
                )
        )
        json
        |> Result.withDefault { val = options.defaultInt }


floatDecoder : DecoderOptions -> JE.Value -> String -> FloatField
floatDecoder options json key =
    JD.decodeValue
        (JD.field key JD.float
            |> JD.map
                (\num ->
                    { val = num }
                )
        )
        json
        |> Result.withDefault { val = options.defaultFloat }



--|> Result.withDefault { val = options.defaultFloat }


stringDecoder : DecoderOptions -> JE.Value -> String -> StringField
stringDecoder options json key =
    JD.decodeValue
        (JD.field key JD.string
            |> JD.map
                (\str ->
                    { val = str }
                )
        )
        json
        |> Result.withDefault { val = options.defaultString }


colorValDecoder : JD.Decoder Color
colorValDecoder =
    JD.map4 Color.rgba
        (JD.field "r" JD.float)
        (JD.field "g" JD.float)
        (JD.field "b" JD.float)
        (JD.field "a" JD.float)


colorDecoder : DecoderOptions -> JE.Value -> String -> ColorField
colorDecoder options json key =
    JD.decodeValue
        (JD.field key colorValDecoder
            |> JD.map color
        )
        json
        |> Result.withDefault (color options.defaultColor)