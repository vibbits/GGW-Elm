module TestAuth exposing (suite)

import Auth exposing (Auth(..), User, authDecoder)
import Expect
import Fuzz exposing (Fuzzer, int, list, string)
import Json.Decode exposing (decodeString)
import Test exposing (..)


suite : Test
suite =
    describe "The Auth module"
        [ test "Decode a valid user" <|
            \_ ->
                Expect.equal
                    (decodeString authDecoder "{\"access_token\":\"token\",\"token_type\":\"bearer\",\"user\":{\"name\":\"ggw\",\"role\":\"admin\",\"id\":1}}")
                    (Ok (Authenticated (User 1 (Just "ggw") "admin" "token")))
        ]
