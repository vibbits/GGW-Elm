module Auth exposing
    ( Auth(..)
    , AuthCode
    , Login
    , User
    , authCode
    , authDecoder
    , init
    )

import Json.Decode as Decode
import Url exposing (Url)
import Url.Parser exposing ((</>), Parser, parse, query, s)
import Url.Parser.Query exposing (map2, string)


type alias Login =
    { url : String
    , name : String
    }


type alias User =
    { id : Int
    , name : Maybe String
    , role : String
    , token : String
    }


type Auth
    = NotAuthenticated (List Login)
    | Authenticated User


type alias AuthCode =
    { code : String
    , state : String
    }


authCode : Url -> Maybe AuthCode
authCode url =
    let
        parser : Parser (Maybe AuthCode -> Maybe AuthCode) (Maybe AuthCode)
        parser =
            s "oidc_login" </> query (map2 (Maybe.map2 AuthCode) (string "code") (string "state"))
    in
    parse parser url |> Maybe.andThen identity


authDecoder : Decode.Decoder Auth
authDecoder =
    Decode.oneOf
        [ loginUrlsDecoder
        , authenticatedDecoder
        ]


init : Auth
init =
    NotAuthenticated []


authenticatedDecoder : Decode.Decoder Auth
authenticatedDecoder =
    Decode.field "access_token" Decode.string
        |> Decode.andThen userDecoder


userDecoder : String -> Decode.Decoder Auth
userDecoder token =
    Decode.map3 (\id name role -> Authenticated (User id name role token))
        (Decode.at [ "user", "id" ] Decode.int)
        (Decode.at [ "user", "name" ] (Decode.nullable Decode.string))
        (Decode.at [ "user", "role" ] Decode.string)


loginDecoder : Decode.Decoder Login
loginDecoder =
    Decode.map2 Login
        (Decode.field "url" Decode.string)
        (Decode.field "name" Decode.string)


loginUrlsDecoder : Decode.Decoder Auth
loginUrlsDecoder =
    Decode.map NotAuthenticated (Decode.list loginDecoder)
