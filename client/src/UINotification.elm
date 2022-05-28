module UINotification exposing
    ( Notifications
    , close
    , init
    , makeError
    , makeWarning
    , view
    )

import Array
    exposing
        ( Array
        , empty
        , filter
        , indexedMap
        , map
        , push
        , toList
        )
import Element
    exposing
        ( Color
        , Element
        , alignRight
        , alignTop
        , column
        , el
        , fill
        , height
        , padding
        , paddingEach
        , paragraph
        , px
        , rgb255
        , row
        , shrink
        , spacing
        , text
        , width
        )
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Tuple exposing (pair, second)


{-| A visual indication of importance

  - Info messages are informative but unimportant
  - Warning messages are more urgent but do not indicate a problem with the program
  - Error messages are unrecoverable errors that the user MUST attend to

-}
type NotificationLevel
    = Error
    | Warning


{-| -}
type alias Notification =
    { title : String
    , level : NotificationLevel
    , message : String
    }


{-| An ordered collection of notifications
-}
type alias Notifications =
    Array Notification


init : Notifications
init =
    empty


makeError : String -> String -> Notifications -> Notifications
makeError title msg =
    push
        { title = title
        , level = Error
        , message = msg
        }


makeWarning : String -> String -> Notifications -> Notifications
makeWarning title msg =
    push
        { title = title
        , level = Warning
        , message = msg
        }



-- makeInfo : String -> String -> Notifications -> Notifications
-- makeInfo title msg =
--     push
--         { title = title
--         , level = Info
--         , message = msg
--         }


close : Int -> Notifications -> Notifications
close which ns =
    indexedMap pair ns
        |> filter (\( i, _ ) -> i /= which)
        |> map second


view : (Int -> msg) -> Notifications -> Element msg
view msgCtor notifications =
    column
        [ width (px 290)
        , height shrink
        , spacing 10
        , padding 20
        , alignTop
        , alignRight
        ]
        (toList <| indexedMap (viewNotification msgCtor) notifications)


viewNotification : (Int -> msg) -> Int -> Notification -> Element msg
viewNotification msgCtor index notification =
    let
        color : Color
        color =
            case notification.level of
                Warning ->
                    yellow

                Error ->
                    red

        theMessage : Element msg
        theMessage =
            column
                [ width fill
                , paddingEach
                    { top = 5
                    , right = 0
                    , bottom = 5
                    , left = 10
                    }
                , spacing 5
                , Border.rounded 7
                , Border.widthEach
                    { bottom = 0
                    , left = 10
                    , right = 0
                    , top = 0
                    }
                , Border.color color
                , Font.size 17
                ]
                [ el [ Font.bold ] (text notification.title)
                , paragraph []
                    [ text notification.message ]
                ]
    in
    row
        [ width fill
        , height shrink
        , Background.color white
        , Border.rounded 7
        , Border.width 1
        , Border.color grey
        ]
        [ theMessage
        , el
            [ alignRight
            , alignTop
            , paddingEach
                { top = 0
                , right = 3
                , bottom = 0
                , left = 0
                }
            ]
            (Input.button []
                { onPress = Just (msgCtor index)
                , label = text "×"
                }
            )
        ]


white : Color
white =
    rgb255 255 255 255


grey : Color
grey =
    rgb255 211 215 207



-- blue : Color
-- blue =
--     rgb255 52 101 164


yellow : Color
yellow =
    rgb255 238 210 2


red : Color
red =
    rgb255 204 0 0
