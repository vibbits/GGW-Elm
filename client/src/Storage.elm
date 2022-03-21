port module Storage exposing (fromJson, save, toJson)

{-| This module deals with saving state to long-term browser storage
-}

import Auth exposing (Auth(..), User)
import Json.Decode as Json
import Json.Encode as Encode


{-| Encode data for permanent storage to Json
-}
toJson : Auth -> Json.Value
toJson auth =
    let
        encodeName : Maybe String -> Json.Value
        encodeName name =
            case name of
                Just n ->
                    Encode.string n

                _ ->
                    Encode.null
    in
    case auth of
        Authenticated user ->
            Encode.object
                [ ( "id", Encode.int user.id )
                , ( "name", encodeName user.name )
                , ( "role", Encode.string user.role )
                , ( "token", Encode.string user.token )
                ]

        NotAuthenticated _ ->
            Encode.null


{-| Decode data from permanent storage
-}
fromJson : Json.Value -> Auth
fromJson value =
    let
        authDecoder : Json.Decoder Auth
        authDecoder =
            Json.map4 (\id name role token -> Authenticated (User id name role token))
                (Json.field "id" Json.int)
                (Json.field "name" (Json.maybe Json.string))
                (Json.field "role" Json.string)
                (Json.field "token" Json.string)
    in
    Json.decodeValue authDecoder value
        |> Result.withDefault (NotAuthenticated [])


port save : Json.Value -> Cmd msg
