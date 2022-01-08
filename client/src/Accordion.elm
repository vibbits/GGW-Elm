--| An accordion (hidable view) container


module Accordion exposing (accordion, body, head, Body, Head, Display)

import Element exposing (..)


type alias Head msg =
    Element msg


type alias Body msg =
    Element msg


type alias Display =
    Bool


accordion : Head msg -> Body msg -> Display -> Element msg
accordion accHead accBody display =
    if display then
        column [ width fill ] [ accHead, accBody ]

    else
        column [ width fill ] [ accHead ]


head : List (Element.Attribute msg) -> List (Element msg) -> Head msg
head attrs =
    row ([ width fill ] ++ attrs)


body : List (Element.Attribute msg) -> List (Element msg) -> Body msg
body attrs =
    column ([ width fill ] ++ attrs)
