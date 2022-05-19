module Router exposing
    ( Page(..)
    , Router
    , changePage
    , changeRoute
    , mkRouter
    , viewRoute
    , withPageView
    )

{-| Handling of client side routing
-}

import Api exposing (Api)
import Auth exposing (Auth(..), authCode)
import Browser.Navigation as Nav
import Element exposing (Element, text)
import GenericDict as Dict exposing (Dict)
import Url exposing (Protocol(..), Url)


{-| The available pages within the app
-}
type Page
    = Login
    | Catalogue
    | AddLevel1
    | AddLevel0
    | AddBackbone
    | Admin


{-| Make the custom Page type a comparable
-}
pageToString : Page -> String
pageToString page =
    case page of
        Login ->
            "login"

        Catalogue ->
            "catalogue"

        AddLevel1 ->
            "new/level1"

        AddLevel0 ->
            "new/level0"

        AddBackbone ->
            "new/backbone"

        Admin ->
            "admin"


{-| Mapping of Url to Page
-}
urlToPage : Url -> Maybe Page
urlToPage url =
    case url.path of
        "/login" ->
            Just Login

        "/" ->
            Just Catalogue

        "/admin" ->
            Just Admin

        "/new/level0" ->
            Just AddLevel0

        "/new/level1" ->
            Just AddLevel1

        _ ->
            Nothing


type alias Router model msg =
    { page : Page
    , goto : Auth -> Url -> Cmd msg
    , view : Dict Page (model -> Element msg)
    , routes : Dict Page Url
    }


{-| Builder initialisation function for a Router
This should be followed by one-or-more calls to
withPageView to define client-side routes.
-}
mkRouter : Nav.Key -> Api msg -> Auth -> Router model msg
mkRouter key api auth =
    { page =
        case auth of
            Authenticated _ ->
                Catalogue

            _ ->
                Login
    , goto = mkGoto key api
    , view = Dict.empty
    , routes = Dict.empty
    }


{-| Define client-side routes.
-}
withPageView : String -> Page -> (model -> Element msg) -> Router model msg -> Router model msg
withPageView url page view router =
    let
        url_ : Url
        url_ =
            { protocol = Http
            , host = ""
            , port_ = Nothing
            , path = url
            , query = Nothing
            , fragment = Nothing
            }
    in
    { router
        | view = Dict.insert pageToString page view router.view
        , routes = Dict.insert pageToString page url_ router.routes
    }


mkGoto : Nav.Key -> Api msg -> Auth -> Url -> Cmd msg
mkGoto key api auth url =
    case ( url.path, auth ) of
        ( "/oidc_login", _ ) ->
            authCode url
                |> Maybe.map api.authorize
                |> Maybe.withDefault Cmd.none

        ( "/login", Authenticated _ ) ->
            Nav.pushUrl key "/"

        ( _, NotAuthenticated _ ) ->
            Cmd.batch
                [ Nav.pushUrl key "login"
                , api.login
                ]

        ( _, Authenticated _ ) ->
            Nav.pushUrl key url.path


{-| Navigate to the URL for a given page
-}
changeRoute : Router model msg -> Auth -> Page -> Cmd msg
changeRoute router auth page =
    Dict.get pageToString page router.routes
        |> Maybe.map (router.goto auth)
        |> Maybe.withDefault Cmd.none


{-| Update the Router when a Url change occurs
-}
changePage : Router model msg -> Url -> Router model msg
changePage router url =
    let
        page : Maybe Page
        page =
            urlToPage url
    in
    { router | page = Maybe.withDefault Catalogue page }


{-| Run the view function for the current page
-}
viewRoute : Router model msg -> model -> Element msg
viewRoute router m =
    Dict.get pageToString router.page router.view
        |> Maybe.map ((|>) m)
        |> Maybe.withDefault invalidRouteView


{-| The 404 view
-}
invalidRouteView : Element msg
invalidRouteView =
    text "Not a valid route"
