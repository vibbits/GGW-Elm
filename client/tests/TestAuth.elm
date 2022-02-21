module TestAuth exposing (suite)

import Auth exposing (Auth(..), authDecoder)
import Expect
import Json.Decode exposing (decodeString)
import Test exposing (..)


suite : Test
suite =
    describe "The Auth module"
        [ test "Decode a valid user" <|
            \_ ->
                Expect.equal
                    (decodeString authDecoder "{\"access_token\":\"token\",\"token_type\":\"bearer\",\"user\":{\"name\":\"ggw\",\"role\":\"admin\",\"id\":1}}")
                    (Ok
                        (Authenticated
                            { id = 1, name = Just "ggw", role = "admin", token = "token" }
                        )
                    )
        ]
