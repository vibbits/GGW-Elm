module Main exposing (..)

import Array exposing (Array)
import Browser exposing (Document)
import Browser.Dom exposing (Error(..))
import Browser.Navigation as Nav
import Color
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border exposing (rounded)
import Element.Font as Font
import Element.Input as Input
import Element.Region
import Html exposing (Html)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import Http exposing (Error(..), expectJson, jsonBody)
import Json.Decode as Decode
import Json.Encode as Encode
import List
import List.Extra
import Path
import Shape exposing (defaultPieConfig)
import TypedSvg exposing (g, svg, text_)
import TypedSvg.Attributes exposing (dy, stroke, textAnchor, transform, viewBox)
import TypedSvg.Core exposing (Svg)
import TypedSvg.Types exposing (AnchorAlignment(..), Paint(..), Transform(..), em)
import Url exposing (..)
import Url.Parser exposing ((</>), Parser, parse, query, s)
import Url.Parser.Query exposing (map2, string)


overhangList3 : List Overhang
overhangList3 =
    [ A__B
    , B__C
    , C__G
    ]


overhangList4 : List Overhang
overhangList4 =
    [ A__B
    , B__C
    , C__D
    , D__G
    ]


overhangList5 : List Overhang
overhangList5 =
    [ A__B
    , B__C
    , C__D
    , D__E
    , E__G
    ]


overhangList6 : List Overhang
overhangList6 =
    [ A__B
    , B__C
    , C__D
    , D__E
    , E__F
    , F__G
    ]


type alias User =
    { id : Int
    , name : Maybe String
    , role : String
    }


type alias Model =
    { currApp : Application
    , currOverhang : Overhang
    , numberInserts : Int
    , backboneLevel : Int
    , overhangShape : List Overhang
    , constructName : String
    , constructNumber : String
    , constructLength : Int
    , applicationNote : String
    , designerName : String
    , description : String
    , selectedInserts : List Insert
    , selectedBackbone : Backbone
    , loginUrls : List Login
    , token : Maybe String
    , user : Maybe User
    , error : Maybe String
    , key : Nav.Key
    }


type alias Insert =
    { name : String, mPG0Number : String, overhang : Overhang, length : Int }


testInsertList : List Insert
testInsertList =
    []


type alias Backbone =
    { name : String, mPGBNumber : String, level : Int, length : Int }


testBackbone : Backbone
testBackbone =
    { name = ""
    , mPGBNumber = ""
    , level = 0
    , length = 0
    }



-- Model


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        cmd =
            case url.path of
                "/oidc_login" ->
                    checkAuthUrl url

                _ ->
                    getLoginUrls
    in
    ( { currApp = Standard
      , currOverhang = A__B
      , numberInserts = 6
      , backboneLevel = 1
      , overhangShape = overhangList6
      , constructName = "Demo Construct"
      , constructNumber = "MP-G1-000000001"
      , constructLength = 0
      , applicationNote = "Some Application: words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words"
      , designerName = "Guy, Smart"
      , description = "Some Description: words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words"
      , selectedInserts = testInsertList
      , selectedBackbone = testBackbone
      , loginUrls = []
      , token = Nothing
      , user = Nothing
      , error = Nothing
      , key = key
      }
    , cmd
    )


checkAuthUrl : Url -> Cmd Msg
checkAuthUrl url =
    case extractCodeAndState url of
        Just authReq ->
            getAuthentication authReq

        Nothing ->
            Cmd.none


extractCodeAndState : Url -> Maybe Authentication
extractCodeAndState url =
    let
        makeAuthentication : Maybe String -> Maybe String -> Maybe Authentication
        makeAuthentication =
            Maybe.map2 Authentication

        parser : Parser (Maybe Authentication -> Maybe Authentication) (Maybe Authentication)
        parser =
            s "oidc_login" </> query (map2 makeAuthentication (string "code") (string "state"))
    in
    parse parser url |> Maybe.andThen identity



-- Where does identity come from?


type Application
    = Standard
    | Five
    | Four
    | Three


type Overhang
    = A__B
    | B__C
    | C__D
    | C__G
    | D__E
    | D__G
    | E__F
    | E__G
    | F__G


type ButtonPosition
    = First
    | Mid
    | Last


type Msg
    = ChooseApplication Application
    | ChangeOverhang Overhang
    | ChangeConstructName String
    | ChangeConstructNumber String
    | ChangeApplicationNote String
    | ChangeConstructDesignerName String
    | ChangeDescription String
    | AppendInsert Insert
    | ChangeBackbone Backbone
    | ResetInsertList
    | ResetBackbone
    | GotLoginUrls (Result Http.Error (List Login))
    | UrlChanged
    | LinkClicked Browser.UrlRequest
    | GotAuthentication (Result Http.Error AuthenticationResponse)



-- view


view : Model -> Document Msg
view model =
    { title = "GGW"
    , body =
        [ layout
            [ -- Element.explain Debug.todo -- Adds debugging info to the console.
              Font.size 11
            , inFront <| navLinks
            ]
          <|
            row
                [ Element.width Element.fill
                , Element.height Element.fill
                , spacing 10
                ]
                [ navLinks
                , mainView model
                ]
        ]
    }


mainView : Model -> Element Msg
mainView model =
    column
        [ Element.width Element.fill
        , Element.height Element.fill
        ]
    <|
        case model.user of
            Just user ->
                [ Element.text ("Welcome " ++ Maybe.withDefault "No user name" user.name)
                , addVectorView model
                ]

            Nothing ->
                viewLoginForm model.loginUrls


addVectorView : Model -> Element Msg
addVectorView model =
    column [ spacing 25, Element.width Element.fill, centerX, padding 50 ]
        [ el
            [ Element.Region.heading 2
            , Font.size 50
            , Font.color color.darkCharcoal
            ]
          <|
            Element.text "Level 1 construct design"
        , el
            [ Element.Region.heading 1
            , Font.size 25
            , Font.color color.darkCharcoal
            ]
          <|
            Element.text "Construct information"
        , Input.text []
            { onChange = ChangeConstructName
            , label = Input.labelLeft [] <| Element.text "Construct name: "
            , text = model.constructName
            , placeholder = Nothing
            }
        , Input.text []
            { onChange = ChangeConstructNumber
            , label = Input.labelLeft [] <| Element.text "Construct number: "
            , text = model.constructNumber
            , placeholder = Nothing
            }
        , row [ spacing 50 ]
            [ el [] <| Element.text "Length (bp):"
            , el [ Background.color color.lightGrey, padding 10 ] <| Element.text (String.fromInt model.constructLength)
            ]
        , Input.multiline [ Element.height <| px 150 ]
            { text = model.applicationNote
            , onChange = ChangeApplicationNote
            , label = Input.labelLeft [] <| Element.text "Application Note: "
            , spellcheck = True
            , placeholder = Nothing
            }
        , Input.text []
            { onChange = ChangeConstructDesignerName
            , label = Input.labelLeft [] <| Element.text "Designer Name: "
            , text = model.designerName
            , placeholder = Nothing
            }
        , Input.multiline [ Element.height <| px 150 ]
            { text = model.description
            , onChange = ChangeDescription
            , label = Input.labelLeft [] <| Element.text "Description: "
            , spellcheck = True
            , placeholder = Nothing
            }
        , el
            [ Element.Region.heading 2
            , Font.size 25
            , Font.color color.darkCharcoal
            ]
          <|
            Element.text "Destination vector selection"
        , backboneTable model
        , el
            [ Element.Region.heading 2
            , Font.size 25
            , Font.color color.darkCharcoal
            ]
          <|
            Element.text "Donor vector selection"
        , applicationRadioButton model
        , overhangRadioRow model
        , insertTable model
        , downloadButtonBar
        , el
            [ Element.Region.heading 2
            , Font.size 25
            , Font.color color.darkCharcoal
            ]
          <|
            Element.text "Construct visualisation"
        , Element.html <| visualRepresentation model
        ]


viewLoginForm : List Login -> List (Element Msg)
viewLoginForm loginUrls =
    case loginUrls of
        [] ->
            [ Element.text "Fetching..." ]

        _ ->
            [ column
                [ Element.width Element.fill
                , Element.height Element.fill
                , spacing 10
                ]
              <|
                el
                    [ centerX
                    , centerY
                    , padding 10
                    , Font.size 18
                    ]
                    (text "Login with:")
                    :: List.map loginButton loginUrls
            ]


loginButton : Login -> Element Msg
loginButton lgn =
    el
        [ centerX
        , centerY
        , padding 10
        , Border.rounded 10
        , Border.solid
        , Border.color (rgb 0 0 0)
        , Border.width 1
        , mouseOver [ Background.color (rgb 0.9 0.9 0.9) ]
        ]
    <|
        Element.link [ spacing 10, Font.size 18, Font.color (rgb 0 0 1) ] { url = lgn.url, label = Element.text lgn.name }



-- Visual representation


w : Float
w =
    990


h : Float
h =
    504


chartColors : Array Color.Color
chartColors =
    Array.fromList
        [ Color.rgb255 152 171 198
        , Color.rgb255 138 137 166
        , Color.rgb255 123 104 136
        , Color.rgb255 107 72 107
        , Color.rgb255 159 92 85
        , Color.rgb255 208 116 60
        , Color.rgb255 255 96 0
        ]


radius : Float
radius =
    min w h / 2


pieSlice : Int -> Shape.Arc -> Svg msg
pieSlice index data =
    Path.element (Shape.arc data) [ TypedSvg.Attributes.fill <| Paint <| Maybe.withDefault Color.darkCharcoal <| Array.get index chartColors, stroke <| Paint Color.white ]


pieLabel : Shape.Arc -> ( String, Float ) -> Svg msg
pieLabel slice ( label, _ ) =
    let
        ( x, y ) =
            Shape.centroid { slice | innerRadius = radius - 40, outerRadius = radius - 40 }
    in
    text_
        [ transform [ Translate x y ]
        , dy (em 0.35)
        , textAnchor AnchorMiddle
        , TypedSvg.Attributes.fontSize (TypedSvg.Types.px 18)
        ]
        [ TypedSvg.Core.text label ]


tupleToRecord : ( String, String, Int ) -> { name : String, overhang : String, length : Int }
tupleToRecord ( t_name, t_overhang, t_length ) =
    { name = t_name, overhang = t_overhang, length = t_length }


visualRepresentation : Model -> Html Msg
visualRepresentation model =
    let
        -- Note: The reversing is for making sure insert 1 is at position 0. This way the destination vector is appended on the back of the list!
        insertOverhangs =
            List.map showOverhang <| List.map .overhang model.selectedInserts

        insertNames =
            List.map .name model.selectedInserts

        insertLengths =
            List.map .length model.selectedInserts

        insertTuple =
            List.Extra.zip3 insertNames insertOverhangs insertLengths

        insertRecordList =
            List.map tupleToRecord insertTuple

        sortByWith : (a -> comparable) -> (comparable -> comparable -> Order) -> List a -> List a
        sortByWith accessor sortFunc list =
            List.sortWith (orderBy accessor sortFunc) list

        orderBy : (a -> comparable) -> (comparable -> comparable -> Order) -> a -> a -> Order
        orderBy accessor orderFunc a b =
            orderFunc (accessor a) (accessor b)

        -- Comparison Funcs
        ascending : comparable -> comparable -> Order
        ascending a b =
            case compare a b of
                LT ->
                    LT

                EQ ->
                    EQ

                GT ->
                    GT

        sortedInsertRecordList =
            sortByWith .overhang ascending insertRecordList

        chartLabels =
            List.reverse (model.selectedBackbone.name :: List.reverse (List.map .name sortedInsertRecordList))

        chartLengths =
            List.reverse (List.map toFloat <| model.selectedBackbone.length :: List.reverse (List.map .length sortedInsertRecordList))

        data =
            List.map2 Tuple.pair chartLabels chartLengths

        pieData =
            data |> List.map Tuple.second |> Shape.pie { defaultPieConfig | outerRadius = radius, innerRadius = 0.9 * radius, sortingFn = \_ _ -> EQ }

        -- sortingFn sets the sorting function -> default = sorting by value (inserts length in this case)
    in
    Html.div [ style "width" "100%" ]
        [ svg [ style "padding" "10px", style "border" "solid 1px steelblue", style "margin" "10px", style "border-radius" "25px", viewBox 0 0 w h ]
            [ g [ transform [ Translate (w / 2) (h / 2) ] ]
                [ g [] <| List.indexedMap pieSlice pieData
                , g [] <| List.map2 pieLabel pieData data
                ]
            ]
        , Html.div [ style "justify-content" "center", style "align-items" "center", style "display" "flex" ]
            [ Html.button [ onClick ResetInsertList, style "margin-right" "75px", style "padding" "10px", style "background-color" "white", style "border-radius" "6px", style "border" "solid 3px rgb(152, 171, 198)" ] [ Html.text "Reset Insert List" ]
            , Html.button [ onClick ResetBackbone, style "margin-left" "75px", style "padding" "10px", style "background-color" "white", style "border-radius" "6px", style "border" "solid 3px rgb(152, 171, 198)" ] [ Html.text "Reset All" ]
            ]
        ]



-- elements


navLinks : Element msg
navLinks =
    column [ Background.color color.blue, Element.height Element.fill, padding 10, spacing 10 ]
        [ link [ Font.size 15, Font.color color.white, Element.width Element.fill, Font.underline, Font.bold ] { url = "index.html", label = Element.text "Home" }
        , link [ Font.size 15, Font.color color.white, Element.width Element.fill, Font.underline, Font.bold ] { url = "catalog.html", label = Element.text "Vector Catalog" }
        , link [ Font.size 15, Font.color color.white, Element.width Element.fill, Font.underline, Font.bold ] { url = "index.html", label = Element.text "New Level 1 construct" }
        , link [ Font.size 15, Font.color color.white, Element.width Element.fill, Font.underline, Font.bold ] { url = "index.html", label = Element.text "New Level 2 construct" }
        ]


downloadButtonBar : Element msg
downloadButtonBar =
    row
        [ centerX
        , spacing 150
        ]
        [ Input.button
            [ padding 10
            , Border.width 3
            , Border.rounded 6
            , Border.color color.blue
            , Background.color color.white
            , centerX
            , mouseDown
                [ Background.color color.blue
                , Font.color color.white
                ]
            , mouseOver
                [ Background.color color.lightBlue
                , Border.color color.lightGrey
                ]
            ]
            { onPress = Nothing
            , label = Element.text "Save To Database"
            }
        , Element.downloadAs
            [ Border.color color.blue
            , Border.width 3
            , Border.solid
            , padding 10
            , rounded 6
            , mouseDown
                [ Background.color color.blue
                , Font.color color.white
                ]
            , mouseOver
                [ Background.color color.lightBlue
                , Border.color color.lightGrey
                ]
            ]
            { label = Element.text "Download Genbank"
            , filename = ""
            , url = "./Example_Data/Example_Genbank_format.gb"
            }
        ]


overhangRadioRow : Model -> Element Msg
overhangRadioRow model =
    let
        midLength =
            List.length model.overhangShape - 1

        first =
            List.map (makeButton First) <| List.take 1 model.overhangShape

        mid =
            List.map (makeButton Mid) <| List.drop 1 <| List.take midLength model.overhangShape

        last =
            List.map (makeButton Last) <| List.drop midLength model.overhangShape

        makeButton : ButtonPosition -> Overhang -> Input.Option Overhang Msg
        makeButton position overhang =
            Input.optionWith overhang <| button position <| showOverhang overhang
    in
    Input.radioRow
        [ Border.rounded 6
        , Border.shadow
            { offset = ( 0, 0 ), size = 3, blur = 10, color = color.lightGrey }
        ]
        { onChange = ChangeOverhang
        , selected = Just model.currOverhang
        , label =
            Input.labelAbove
                [ paddingEach { bottom = 20, top = 0, left = 0, right = 0 } ]
            <|
                Element.text "Choose Overhang type"
        , options = first ++ mid ++ last
        }


button : ButtonPosition -> String -> Input.OptionState -> Element msg
button position label state =
    let
        borders =
            case position of
                First ->
                    { left = 2, right = 2, top = 2, bottom = 2 }

                Mid ->
                    { left = 0, right = 2, top = 2, bottom = 2 }

                Last ->
                    { left = 0, right = 2, top = 2, bottom = 2 }

        corners =
            case position of
                First ->
                    { topLeft = 6, bottomLeft = 6, topRight = 0, bottomRight = 0 }

                Mid ->
                    { topLeft = 0, bottomLeft = 0, topRight = 0, bottomRight = 0 }

                Last ->
                    { topLeft = 0, bottomLeft = 0, topRight = 6, bottomRight = 6 }
    in
    el
        [ paddingEach { left = 20, right = 20, top = 10, bottom = 10 }
        , Border.roundEach corners
        , Border.widthEach borders
        , Border.color color.blue
        , Background.color <|
            if state == Input.Selected then
                color.lightBlue

            else
                color.white
        ]
    <|
        el [ centerX, centerY ] <|
            Element.text label


applicationRadioButton : Model -> Element Msg
applicationRadioButton model =
    Input.radioRow
        [ padding 10
        , spacing 20
        ]
        { onChange = ChooseApplication
        , selected = Just model.currApp
        , label = Input.labelAbove [] <| Element.text "Choose a type of application:"
        , options =
            [ Input.option Standard <| Element.text "Standard application with 6 inserts"
            , Input.option Five <| Element.text "Custom - 5 inserts"
            , Input.option Four <| Element.text "Custom - 4 inserts"
            , Input.option Three <| Element.text "Custom - 3 inserts"
            ]
        }


insertTable : Model -> Element Msg
insertTable model =
    let
        headerAttrs =
            [ Font.bold
            , Font.color color.blue
            , Border.widthEach { bottom = 2, top = 0, left = 0, right = 0 }
            , Border.color color.blue
            ]
    in
    column
        [ Element.width Element.fill
        ]
        [ row
            [ spacing 20
            , Element.width Element.fill
            , padding 30
            , clipY
            ]
            [ el ((Element.width <| fillPortion 3) :: headerAttrs) <| Element.text "MP-G0-Number"
            , el ((Element.width <| fillPortion 5) :: headerAttrs) <| Element.text "Insert Name"
            , el ((Element.width <| fillPortion 1) :: headerAttrs) <| Element.text "Length"
            ]
        , el
            [ Element.width Element.fill
            , Border.width 1
            , Border.rounded 50
            ]
          <|
            table
                [ Element.width Element.fill
                , Element.height <| px 250
                , scrollbarY
                , spacing 10
                , padding 25
                ]
                { data = insertList model.currOverhang
                , columns =
                    [ { header = none
                      , width = fillPortion 3
                      , view = .mPG0Number >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 5
                      , view =
                            \insert ->
                                Input.button [ Font.color color.blue, Font.bold, Font.underline ] { onPress = Just (AppendInsert insert), label = Element.text insert.name }
                      }
                    , { header = none
                      , width = fillPortion 1
                      , view = .length >> String.fromInt >> Element.text >> el [ centerY ]
                      }
                    ]
                }
        ]


backboneTable : Model -> Element Msg
backboneTable model =
    let
        headerAttrs =
            [ Font.bold
            , Font.color color.blue
            , Border.widthEach { bottom = 2, top = 0, left = 0, right = 0 }
            , Border.color color.blue
            ]
    in
    column
        [ Element.width Element.fill
        ]
        [ row
            [ spacing 20
            , Element.width Element.fill
            , padding 30
            ]
            [ el ((Element.width <| fillPortion 3) :: headerAttrs) <| Element.text "MP-GB-Number"
            , el ((Element.width <| fillPortion 5) :: headerAttrs) <| Element.text "Backbone Name"
            , el ((Element.width <| fillPortion 1) :: headerAttrs) <| Element.text "Length"
            ]
        , el
            [ Element.width Element.fill
            , Border.width 1
            , Border.rounded 30
            ]
          <|
            table
                [ Element.width Element.fill
                , Element.height <| px 250
                , scrollbarY
                , spacing 10
                , padding 25
                ]
                { data = backboneList model.backboneLevel
                , columns =
                    [ { header = none
                      , width = fillPortion 3
                      , view = .mPGBNumber >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 5
                      , view =
                            \backbone ->
                                Input.button [ Font.color color.blue, Font.bold, Font.underline ] { onPress = Just (ChangeBackbone backbone), label = Element.text backbone.name }
                      }
                    , { header = none
                      , width = fillPortion 1
                      , view = .length >> String.fromInt >> Element.text >> el [ centerY ]
                      }
                    ]
                }
        ]



-- update


type alias AuthenticationResponse =
    { token : String
    , user : User
    }


type alias Authentication =
    { code : String
    , state : String
    }


authDecoder : Decode.Decoder Authentication
authDecoder =
    Decode.map2 Authentication
        (Decode.field "code" Decode.string)
        (Decode.field "state" Decode.string)


authUrlsDecoder : Decode.Decoder AuthenticationResponse
authUrlsDecoder =
    Decode.map2 AuthenticationResponse
        (Decode.field "access_token" Decode.string)
        (Decode.field "user" userDecoder)



-- You have to use a decoder specific to decode user objects


userDecoder : Decode.Decoder User
userDecoder =
    Decode.map3 User
        (Decode.field "id" Decode.int)
        (Decode.field "name" (Decode.nullable Decode.string))
        (Decode.field "role" Decode.string)


type alias Login =
    { url : String
    , name : String
    }


loginDecoder : Decode.Decoder Login
loginDecoder =
    Decode.map2 Login
        (Decode.field "url" Decode.string)
        (Decode.field "name" Decode.string)


loginUrlsDecoder : Decode.Decoder (List Login)
loginUrlsDecoder =
    Decode.list loginDecoder


showHttpError : Http.Error -> String
showHttpError err =
    case err of
        BadUrl v ->
            "BadUrl: " ++ v

        Timeout ->
            "Timeout"

        NetworkError ->
            "NetworkError"

        BadStatus i ->
            "BadStatus: " ++ String.fromInt i

        BadBody v ->
            "BadBody: " ++ v


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        updateOverhangShape : Application -> List Overhang
        updateOverhangShape app =
            case app of
                Standard ->
                    overhangList6

                Five ->
                    overhangList5

                Four ->
                    overhangList4

                Three ->
                    overhangList3
    in
    case msg of
        ChangeOverhang newOverhang ->
            ( { model | currOverhang = newOverhang }, Cmd.none )

        ChooseApplication newApp ->
            ( { model | currApp = newApp, overhangShape = updateOverhangShape newApp }, Cmd.none )

        ChangeConstructName newName ->
            ( { model | constructName = newName }, Cmd.none )

        ChangeConstructNumber newNumber ->
            ( { model | constructNumber = newNumber }, Cmd.none )

        ChangeApplicationNote newAN ->
            ( { model | applicationNote = newAN }, Cmd.none )

        ChangeConstructDesignerName newDesignerName ->
            ( { model | designerName = newDesignerName }, Cmd.none )

        ChangeDescription newDescription ->
            ( { model | description = newDescription }, Cmd.none )

        AppendInsert newInsert ->
            if not (List.member newInsert.overhang (List.map .overhang model.selectedInserts)) then
                ( { model
                    | selectedInserts = List.append model.selectedInserts [ newInsert ]
                    , constructLength = List.sum (model.selectedBackbone.length :: newInsert.length :: List.map .length model.selectedInserts)
                  }
                , Cmd.none
                )

            else
                ( { model
                    | selectedInserts = newInsert :: List.filter (\insert -> not (insert.overhang == newInsert.overhang)) model.selectedInserts
                    , constructLength = List.sum (model.selectedBackbone.length :: List.map .length (newInsert :: List.filter (\insert -> not (insert.overhang == newInsert.overhang)) model.selectedInserts))
                  }
                , Cmd.none
                )

        ChangeBackbone newBackbone ->
            ( { model | selectedBackbone = newBackbone }, Cmd.none )

        ResetInsertList ->
            ( { model | selectedInserts = [] }, Cmd.none )

        ResetBackbone ->
            ( { model | selectedInserts = [], selectedBackbone = { name = "", length = 0, mPGBNumber = "", level = 0 } }, Cmd.none )

        UrlChanged ->
            ( model, Cmd.none )

        GotLoginUrls res ->
            case res of
                Ok urls ->
                    ( { model | loginUrls = urls }, Cmd.none )

                Err err ->
                    ( { model | error = Just <| showHttpError err }, Cmd.none )

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        GotAuthentication res ->
            let
                navToRoot : Cmd Msg
                navToRoot =
                    Nav.pushUrl model.key "/"
            in
            case res of
                Ok response ->
                    ( { model | user = Just response.user, token = Just response.token }, navToRoot )

                Err err ->
                    ( { model | error = Just <| showHttpError err }, navToRoot )


getLoginUrls : Cmd Msg
getLoginUrls =
    Http.get
        { url = "http://localhost:8000/login"
        , expect = expectJson GotLoginUrls loginUrlsDecoder
        }


getAuthentication : Authentication -> Cmd Msg
getAuthentication auth =
    Http.post
        { url = "http://localhost:8000/authorize"
        , body =
            jsonBody
                (Encode.object
                    [ ( "state", Encode.string auth.state )
                    , ( "code", Encode.string auth.code )
                    ]
                )
        , expect = expectJson GotAuthentication authUrlsDecoder
        }


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = LinkClicked
        , onUrlChange = always UrlChanged
        }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



--


color : { blue : Element.Color, darkCharcoal : Element.Color, lightBlue : Element.Color, lightGrey : Element.Color, white : Element.Color }
color =
    { blue = Element.rgb255 152 171 198
    , darkCharcoal = Element.rgb255 0x2E 0x34 0x36
    , lightBlue = Element.rgb255 0xC5 0xE8 0xF7
    , lightGrey = Element.rgb255 0xE0 0xE0 0xE0
    , white = Element.rgb255 0xFF 0xFF 0xFF
    }


showOverhang : Overhang -> String
showOverhang overhang =
    case overhang of
        A__B ->
            "A__B"

        B__C ->
            "B__C"

        C__D ->
            "C__D"

        C__G ->
            "C__G"

        D__E ->
            "D__E"

        D__G ->
            "D__G"

        E__F ->
            "E__F"

        E__G ->
            "E__G"

        F__G ->
            "F__G"


stringToOverhang : String -> Maybe Overhang
stringToOverhang strOverhang =
    case strOverhang of
        "A__B" ->
            Just A__B

        "B__C" ->
            Just B__C

        "C__D" ->
            Just C__D

        "C__G" ->
            Just C__G

        "D__E" ->
            Just D__E

        "D__G" ->
            Just D__G

        "E__F" ->
            Just E__F

        "E__G" ->
            Just E__G

        "F__G" ->
            Just F__G

        _ ->
            Nothing


insertList : Overhang -> List Insert
insertList overhang =
    [ { name = showOverhang overhang ++ "__" ++ "Insert 1", mPG0Number = "MG-G0-000001", overhang = overhang, length = 952 }
    , { name = showOverhang overhang ++ "__" ++ "Insert 2", mPG0Number = "MG-G0-000002", overhang = overhang, length = 1526 }
    , { name = showOverhang overhang ++ "__" ++ "Insert 3", mPG0Number = "MG-G0-000003", overhang = overhang, length = 1874 }
    , { name = showOverhang overhang ++ "__" ++ "Insert 4", mPG0Number = "MG-G0-000004", overhang = overhang, length = 2698 }
    , { name = showOverhang overhang ++ "__" ++ "Insert 5", mPG0Number = "MG-G0-000005", overhang = overhang, length = 528 }
    , { name = showOverhang overhang ++ "__" ++ "Insert 6", mPG0Number = "MG-G0-000006", overhang = overhang, length = 865 }
    , { name = showOverhang overhang ++ "__" ++ "Insert 7", mPG0Number = "MG-G0-000007", overhang = overhang, length = 1058 }
    ]


backboneList : Int -> List Backbone
backboneList bbLevel =
    [ { name = "Backbone 1", mPGBNumber = "MG-GB-000001", level = bbLevel, length = 10520 }
    , { name = "Backbone 2", mPGBNumber = "MG-GB-000002", level = bbLevel, length = 11840 }
    , { name = "Backbone 3", mPGBNumber = "MG-GB-000003", level = bbLevel, length = 9520 }
    , { name = "Backbone 4", mPGBNumber = "MG-GB-000004", level = bbLevel, length = 13258 }
    , { name = "Backbone 5", mPGBNumber = "MG-GB-000005", level = bbLevel, length = 11470 }
    , { name = "Backbone 6", mPGBNumber = "MG-GB-000006", level = bbLevel, length = 13690 }
    , { name = "Backbone 7", mPGBNumber = "MG-GB-000007", level = bbLevel, length = 12580 }
    ]
