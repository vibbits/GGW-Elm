module Api exposing (Api, ApiExpect, RemoteRequest(..), dummyApi, initApi, request)

{-| Remote API interface. Handles the following complexities of a distributed
system:

1.  Remote address configuration
2.  Result caching (TODO)

-}

import Auth exposing (Auth(..), AuthCode)
import Http exposing (Expect, get, jsonBody, post)
import Json.Decode as Decode
import Json.Encode as Encode
import Molecules exposing (Vector(..), vectorEncoder)


{-| API methods
-}
type alias Api msg =
    { login : Cmd msg
    , authorize : AuthCode -> Cmd msg
    , vectors : Auth -> Cmd msg
    , save : Auth -> Vector -> Cmd msg
    , allUsers : Auth -> Cmd msg
    , allGroups : Auth -> Cmd msg
    , allConstructs : Auth -> Cmd msg
    }


{-| Initialisation configuration:
What does each endpoint expect?
-}
type alias ApiExpect msg =
    { loginExpect : Expect msg
    , authorizeExpect : Expect msg
    , vectorsExpect : Expect msg
    , saveExpect : Expect msg
    , allUsersExpect : Expect msg
    , allGroupsExpect : Expect msg
    , allConstructsExpect : Expect msg
    }


type alias ApiUrl =
    String


type RemoteRequest
    = LoginUrls
    | AuthToken
    | Vectors
    | Save
    | AllUsers
    | AllGroups
    | AllConstructs


authenticatedGet : String -> ApiUrl -> Expect msg -> Cmd msg
authenticatedGet token url expect =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" ("Bearer " ++ token) ]
        , url = url
        , body = Http.emptyBody
        , expect = expect
        , timeout = Nothing
        , tracker = Nothing
        }


authenticatedPost : String -> ApiUrl -> Expect msg -> Encode.Value -> Cmd msg
authenticatedPost token url expect payload =
    Http.request
        { method = "POST"
        , headers = [ Http.header "Authorization" ("Bearer " ++ token) ]
        , url = url
        , body = Http.jsonBody payload
        , expect = expect
        , timeout = Nothing
        , tracker = Nothing
        }


mkLogin : ApiUrl -> Expect msg -> Cmd msg
mkLogin url expect =
    get
        { url = url ++ "/login"
        , expect = expect
        }


mkAuthorize : ApiUrl -> Expect msg -> AuthCode -> Cmd msg
mkAuthorize url expect auth =
    post
        { url = url ++ "/authorize"
        , body =
            jsonBody
                (Encode.object
                    [ ( "state", Encode.string auth.state )
                    , ( "code", Encode.string auth.code )
                    ]
                )
        , expect = expect
        }


mkVectors : ApiUrl -> Expect msg -> Auth -> Cmd msg
mkVectors url expect auth =
    case auth of
        Authenticated usr ->
            authenticatedGet usr.token (url ++ "/vectors/") expect

        _ ->
            Cmd.none


mkSave : ApiUrl -> Expect msg -> Auth -> Vector -> Cmd msg
mkSave url expect auth vec =
    case auth of
        Authenticated usr ->
            let
                apiUrl : ApiUrl
                apiUrl =
                    case vec of
                        LevelNVec _ ->
                            url ++ "/submit/vector/"

                        _ ->
                            url ++ "/submit/genbank/"
            in
            authenticatedPost usr.token apiUrl expect (vectorEncoder vec)

        _ ->
            Cmd.none


mkAllUsers : ApiUrl -> Expect msg -> Auth -> Cmd msg
mkAllUsers url expect auth =
    case auth of
        Authenticated usr ->
            if usr.role == "admin" then
                authenticatedGet usr.token (url ++ "/admin/users") expect

            else
                Cmd.none

        _ ->
            Cmd.none


mkAllGroups : ApiUrl -> Expect msg -> Auth -> Cmd msg
mkAllGroups url expect auth =
    case auth of
        Authenticated usr ->
            if usr.role == "admin" then
                authenticatedGet usr.token (url ++ "/admin/groups") expect

            else
                Cmd.none

        _ ->
            Cmd.none


mkAllConstructs : ApiUrl -> Expect msg -> Auth -> Cmd msg
mkAllConstructs url expect auth =
    case auth of
        Authenticated usr ->
            if usr.role == "admin" then
                authenticatedGet usr.token (url ++ "/admin/constructs") expect

            else
                Cmd.none

        _ ->
            Cmd.none


{-| Initialise API functions given some configuration
-}
initApi : ApiExpect msg -> Decode.Value -> Result String (Api msg)
initApi expect val =
    let
        urlDecoder : Decode.Decoder ApiUrl
        urlDecoder =
            Decode.field "apiUrl" Decode.string
    in
    Decode.decodeValue urlDecoder val
        |> Result.mapError Decode.errorToString
        |> Result.map
            (\baseUrl ->
                { login = mkLogin baseUrl expect.loginExpect
                , authorize = mkAuthorize baseUrl expect.authorizeExpect
                , vectors = mkVectors baseUrl expect.vectorsExpect
                , save = mkSave baseUrl expect.saveExpect
                , allUsers = mkAllUsers baseUrl expect.allUsersExpect
                , allGroups = mkAllGroups baseUrl expect.allGroupsExpect
                , allConstructs = mkAllConstructs baseUrl expect.allConstructsExpect
                }
            )


{-| Default do-nothing API functions
-}
dummyApi : Api msg
dummyApi =
    { login = Cmd.none
    , authorize = always Cmd.none
    , vectors = always Cmd.none
    , save = \_ _ -> Cmd.none
    , allUsers = always Cmd.none
    , allGroups = always Cmd.none
    , allConstructs = always Cmd.none
    }


request : Api msg -> Auth -> RemoteRequest -> Cmd msg
request api auth req =
    case req of
        LoginUrls ->
            api.login

        AuthToken ->
            Cmd.none

        Vectors ->
            Cmd.none

        Save ->
            Cmd.none

        AllUsers ->
            api.allUsers auth

        AllGroups ->
            api.allGroups auth

        AllConstructs ->
            api.allConstructs auth
