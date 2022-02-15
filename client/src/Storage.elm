port module Storage exposing (..)

import Json.Encode as Encode



-- type alias Storage a =


port save : Encode.Value -> Cmd msg
