--| An accordion (hidable view) container


module Accordion exposing (Body, Display, Head, accordion, body, head)

import Element exposing (..)
import Element.Border


type alias Head msg =
    Display -> Element msg


type alias Body msg =
    Element msg


type alias Display =
    Bool


accordion : Head msg -> Body msg -> Display -> Element msg
accordion accHead accBody display =
    if display then
        column [ width fill ] [ accHead display, accBody ]

    else
        column [ width fill ] [ accHead display ]


head : List (Element.Attribute msg) -> List (Element msg) -> Head msg
head attrs contents display =
    row (List.append [ width fill, padding 25, Element.Border.solid, Element.Border.rounded 6 ] attrs)
        (contents ++ [ arrow display ])


body : List (Element.Attribute msg) -> List (Element msg) -> Body msg
body attrs =
    column (List.append [ width fill, padding 25 ] attrs)


arrow : Display -> Element msg
arrow display =
    let
        show : Element msg
        show =
            if display then
                text "▼"

            else
                text "▶"
    in
    el [ alignRight ] show
