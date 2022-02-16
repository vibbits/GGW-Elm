module Interface exposing
    ( addButton
    , buttonLink_
    , button_
    , download_
    , linkButton_
    , navBar
    , option_
    , title
    , viewMaybe
    )

import Element
    exposing
        ( Color
        , Element
        , centerX
        , centerY
        , column
        , downloadAs
        , el
        , fill
        , height
        , htmlAttribute
        , mouseOver
        , padding
        , paddingEach
        , px
        , shrink
        , spacing
        , text
        , width
        )
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input exposing (OptionState(..), button)
import Element.Region exposing (heading)
import Html.Attributes exposing (style)


white : Color
white =
    Element.rgb255 0xFF 0xFF 0xFF


backgroundPrimary : Color
backgroundPrimary =
    Element.rgb255 244 244 244


backgroundSecondary : Color
backgroundSecondary =
    Element.rgba255 128 128 128 0.1


foregroundPrimary : Color
foregroundPrimary =
    Element.rgb255 0x1B 0x29 0x44


foregroundSecondary : Color
foregroundSecondary =
    Element.rgb255 0x1C 0xBB 0xBA


foregroundHighlight : Color
foregroundHighlight =
    Element.rgb255 0xFF 0x68 0x1E


viewMaybe : (a -> String) -> Maybe a -> Element msg
viewMaybe show mby =
    Maybe.map show mby
        |> Maybe.withDefault "Not defined"
        |> text
        |> el [ centerY ]


{-| A button with a simple message
-}
button_ : Maybe msg -> String -> Element msg
button_ msg label =
    button
        [ padding 10
        , Border.solid
        , Border.color foregroundPrimary
        , Border.width 3
        , Border.rounded 6
        , Background.color backgroundPrimary
        , Font.color foregroundPrimary
        , mouseOver
            [ Font.color foregroundSecondary
            , Border.color foregroundSecondary
            ]
        ]
        { onPress = msg
        , label = text label
        }


{-| A download with a simple message
-}
download_ : String -> String -> String -> Element msg
download_ url filename label =
    downloadAs
        [ padding 10
        , Border.solid
        , Border.color foregroundPrimary
        , Border.width 3
        , Border.rounded 6
        , Background.color backgroundPrimary
        , Font.color foregroundPrimary
        , mouseOver
            [ Border.color foregroundSecondary
            , Font.color foregroundSecondary
            ]
        ]
        { url = url
        , label = text label
        , filename = filename
        }


{-| A link with a simple message
-}
buttonLink_ : Maybe msg -> String -> Element msg
buttonLink_ msg label =
    button
        [ Font.size 15
        , Font.color foregroundPrimary
        , Font.underline
        , Font.bold
        , width fill
        , mouseOver
            [ Font.color foregroundSecondary ]
        ]
        { onPress = msg
        , label = text label
        }


linkButton_ : String -> String -> Element msg
linkButton_ url label =
    el
        [ centerX
        , centerY
        , padding 10
        , Border.rounded 10
        , Border.solid
        , Border.width 1
        , Border.color foregroundPrimary
        , Font.color foregroundPrimary
        , mouseOver
            [ Border.color foregroundSecondary
            , Font.color foregroundSecondary
            ]
        ]
    <|
        Element.link
            [ spacing 10
            , Font.size 18
            ]
            { url = url
            , label = Element.text label
            }


{-| A radio option
-}
option_ : String -> OptionState -> Element msg
option_ label state =
    el
        [ paddingEach { left = 20, right = 20, top = 10, bottom = 10 }
        , Border.color foregroundPrimary
        , Background.color <|
            if state == Selected then
                foregroundHighlight

            else
                white
        ]
        (el
            [ centerX, centerY ]
            (Element.text label)
        )


addButton : msg -> Element msg
addButton msg =
    button
        [ height (px 70)
        , width (px 70)
        , Border.width 7
        , Border.solid
        , Border.color foregroundPrimary
        , Border.rounded 35
        , Font.color foregroundPrimary
        , mouseOver
            [ Border.color foregroundSecondary
            , Font.color foregroundSecondary
            ]
        ]
        { onPress = Just msg
        , label =
            el
                [ centerX
                , centerY
                , Font.bold
                , Font.size 40
                ]
                (text "+")
        }


navBar : List (Element msg) -> Element msg
navBar links =
    column
        [ padding 10
        , spacing 10
        , height fill
        , width shrink
        , htmlAttribute <| style "position" "sticky"
        , htmlAttribute <| style "top" "0"
        , Background.color backgroundSecondary
        ]
        (text "Golden Gateway v1.0.0"
            :: links
        )


{-| A title heading
-}
title : String -> Element msg
title t =
    el
        [ heading 1
        , Font.size 50
        , Font.color foregroundPrimary
        ]
        (text t)
