module Interface exposing (button_, link_, title, viewMaybe)

import Element
    exposing
        ( Color
        , Element
        , centerY
        , el
        , fill
        , mouseDown
        , mouseOver
        , padding
        , text
        , width
        )
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input exposing (button)
import Element.Region exposing (heading)


blue : Color
blue =
    Element.rgb255 152 171 198


darkCharcoal : Color
darkCharcoal =
    Element.rgb255 0x2E 0x34 0x36


lightBlue : Color
lightBlue =
    Element.rgb255 0xC5 0xE8 0xF7


lightGrey : Color
lightGrey =
    Element.rgb255 0xE0 0xE0 0xE0


white : Color
white =
    Element.rgb255 0xFF 0xFF 0xFF


viewMaybe : (a -> String) -> Maybe a -> Element msg
viewMaybe show mby =
    Maybe.map show mby
        |> Maybe.withDefault "Not defined"
        |> text
        |> el [ centerY ]


{-| A button with a simple message
-}
button_ : msg -> String -> Element msg
button_ msg label =
    button
        [ Border.solid
        , Border.color blue
        , Border.width 3
        , Border.rounded 6
        , padding 10
        , Background.color white
        , mouseDown
            [ Background.color blue
            , Font.color white
            ]
        , mouseOver
            [ Background.color lightBlue
            , Border.color lightGrey
            ]
        ]
        { onPress = Just msg
        , label = text label
        }


{-| A link with a simple message
-}
link_ : msg -> String -> Element msg
link_ msg label =
    button
        [ Font.size 15
        , Font.color white
        , Font.underline
        , Font.bold
        , width fill
        ]
        { onPress = Just msg
        , label = text label
        }


{-| A title heading
-}
title : String -> Element msg
title t =
    el
        [ heading 1
        , Font.size 50
        , Font.color darkCharcoal
        ]
        (text t)
