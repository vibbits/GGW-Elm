module Main exposing (..)

import Accordion
import Array exposing (Array, length)
import Browser exposing (Document, application)
import Browser.Dom exposing (Error(..))
import Browser.Navigation as Nav
import Color
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border exposing (rounded)
import Element.Events as EE
import Element.Font as Font
import Element.Input as Input exposing (OptionState(..))
import Element.Region
import File exposing (File)
import File.Select as Select
import Html exposing (Html, a, button, div, i, label, span, text)
import Html.Attributes as HA
import Html.Events exposing (onClick)
import Http exposing (Error(..), expectJson, jsonBody)
import Json.Decode as Decode
import Json.Encode as Encode
import List
import List.Extra
import Path
import Shape exposing (defaultPieConfig)
import String exposing (toInt)
import Svg.Attributes exposing (mode, style)
import Task
import TypedSvg exposing (g, svg, text_)
import TypedSvg.Attributes exposing (dy, stroke, textAnchor, transform, viewBox)
import TypedSvg.Core exposing (Svg)
import TypedSvg.Types exposing (AnchorAlignment(..), Paint(..), Transform(..), em)
import Url exposing (..)
import Url.Parser exposing ((</>), Parser, int, parse, query, s)
import Url.Parser.Query as Query exposing (map2, string)
import Zoom exposing (events)
import TypedSvg.Types exposing (Length(..))



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

completeOverhangList : List Overhang
completeOverhangList =
    [ A__B
    , B__C
    , C__D
    , C__G
    , D__E
    , D__G
    , E__F
    , E__G
    , F__G
    ]

type alias User =
    { id : Int
    , name : Maybe String
    , role : String
    }


type DisplayPage
    = Catalogue
    | ConstructLevel1
    | ConstructLevel2
    | AddLevel0Page
    | AddBackbonePage


type alias Model =
    { page : DisplayPage
    , currApp : Application
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

    -- Attributes for the vector catalog
    , backboneFilterString : Maybe String
    , level0FilterString : Maybe String
    , level1FilterString : Maybe String
    , backboneAccordionStatus : Bool
    , level0AccordionStatus : Bool
    , level1AccordionStatus : Bool
    , backboneList : List Backbone
    , insertList : List Insert

    -- Attributes for adding backbones
    , nameBackboneToAdd : String
    , mpgbNumberBackboneToAdd : String
    , levelBackboneToAdd : Int
    , lengthBackboneToAdd : Int
    , backboneGenbankContent : Maybe String

    -- Attributes for adding Level0
    , nameLevel0ToAdd : String
    , mpg0NumberLevel0ToAdd : String
    , overhangLevel0ToAdd : Maybe Overhang
    , lengthLevel0ToAdd : Int
    , level0GenbankContent : Maybe String
    }


type alias Insert =
    { name : String, mPG0Number : String, overhang : Maybe Overhang, length : Int }


emptyInsertList : List Insert
emptyInsertList =
    []


type alias Backbone =
    { name : String, mPGBNumber : String, level : Int, length : Int }


emptyBackbone : Backbone
emptyBackbone =
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
    ( { page = Catalogue
      , currApp = Standard
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
      , selectedInserts = emptyInsertList
      , selectedBackbone = emptyBackbone
      , loginUrls = []
      , token = Nothing
      , user = Nothing
      , error = Nothing
      , key = key
      , backboneFilterString = Nothing
      , level0FilterString = Nothing
      , level1FilterString = Nothing
      , backboneAccordionStatus = False
      , level0AccordionStatus = False
      , level1AccordionStatus = False
      , backboneList = testBackboneList 1
      , insertList = testInsertList A__B

      -- Backbone To Add attributes
      , nameBackboneToAdd = ""
      , mpgbNumberBackboneToAdd = ""
      , levelBackboneToAdd = 0
      , lengthBackboneToAdd = 0
      , backboneGenbankContent = Nothing

      -- Level0 To Add Attributes
      , nameLevel0ToAdd = ""
      , mpg0NumberLevel0ToAdd = ""
      , overhangLevel0ToAdd = Nothing
      , lengthLevel0ToAdd = 0
      , level0GenbankContent = Nothing
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
    | Invalid


type ButtonPosition
    = First
    | Mid
    | Last


type Msg
    = -- Level 1 construction Msg
      ChooseApplication Application
    | ChangeOverhang Overhang
    | ChangeNumberInserts Int
    | ChangeBackboneLevel Int
    | ChangeConstructName String
    | ChangeConstructNumber String
    | ChangeApplicationNote String
    | ChangeConstructDesignerName String
    | ChangeDescription String
    | AppendInsert Insert
    | ChangeBackbone Backbone
    | ResetInsertList
    | ResetBackbone
      -- Login Msg
    | GotLoginUrls (Result Http.Error (List Login))
    | UrlChanged Url.Url
    | LinkClicked Browser.UrlRequest
    | GotAuthentication (Result Http.Error AuthenticationResponse)
      -- Msg Switching pages
    | SwitchPage DisplayPage
      -- Vector catalogue Msg
    | BackboneAccordionToggled
    | Level0AccordionToggled
    | Level1AccordionToggled
    | ToggleAll
    | FilterBackboneTable String
    | FilterLevel0Table String
    | FilterLevel1Table String
      -- Msg for adding Backbones
    | AddBackbone Backbone
    | ChangeBackboneNameToAdd String
    | ChangeBackboneMpgNumberToAdd String
    | ChangeBackboneLevelToAdd String
    | ChangeBackboneLengthToAdd String
    | GbNewBackboneRequested
    | GbNewBackboneSelected File
    | GbNewBackboneLoaded String
      -- Msg for adding Level 0
    | AddLevel0 Insert
    | ChangeLevel0NameToAdd String
    | ChangeLevel0MpgNumberToAdd String
    | ChangeLevel0OverhangToAdd Overhang
    | ChangeLevel0LengthToAdd String
    | GBNewLevel0Requested
    | GBNewLevel0Selected File
    | GbNewLevel0Loaded String



-- view


view : Model -> Document Msg
view model =
    case model.page of
        ConstructLevel1 ->
            constructLevel1View model

        ConstructLevel2 ->
            constructLevel2View model

        Catalogue ->
            catalogueView model

        AddLevel0Page ->
            addLevel0View model

        AddBackbonePage ->
            addBackboneView model


catalogueView : Model -> Document Msg
catalogueView model =
    { title = "Vector Catalog"
    , body =
        [ layout
            [ inFront <| navLinks
            , Element.height Element.fill
            ]
          <|
            row []
                [ navLinks
                , column [ spacing 25, Element.width Element.fill, centerX, padding 50 ]
                    [ el
                        [ Element.Region.heading 1
                        , Font.size 50
                        , Font.color color.darkCharcoal
                        ]
                      <|
                        Element.text "Vector Catalog"
                    , Input.button
                        [ Border.solid
                        , Border.color color.blue
                        , padding 10
                        , Border.width 3
                        , Border.rounded 6
                        , Background.color color.white
                        , mouseDown
                            [ Background.color color.blue
                            , Font.color color.white
                            ]
                        , mouseOver
                            [ Background.color color.lightBlue
                            , Border.color color.lightGrey
                            ]
                        ]
                        { onPress = Just ToggleAll
                        , label = Element.text "Toggle all"
                        }
                    , Accordion.accordion
                        (Accordion.head
                            [ EE.onClick BackboneAccordionToggled
                            , Background.color color.blue
                            , padding 25
                            , Border.solid
                            , Border.rounded 6
                            ]
                            [ Element.text "Backbones\t▼"
                            ]
                        )
                        (Accordion.body [spacing 25]
                            [ Input.text []
                                { onChange = FilterBackboneTable
                                , text = Maybe.withDefault "" model.backboneFilterString
                                , label = Input.labelLeft [] <| Element.text "Filter:"
                                , placeholder = Nothing
                                }
                            , backboneTable model
                            , Element.row
                                [ centerX, spacing 50 ]
                                [ customAddButton "+" (SwitchPage AddBackbonePage) ]
                            ]
                        )
                        model.backboneAccordionStatus
                    , Accordion.accordion
                        (Accordion.head
                            [ EE.onClick Level0AccordionToggled
                            , Background.color color.blue
                            , padding 25
                            , Border.solid
                            , Border.rounded 6
                            ]
                            [ Element.text "Level 0\t▼"
                            ]
                        )
                        (Accordion.body [spacing 25]
                            [ Input.text []
                                { onChange = FilterLevel0Table
                                , text = Maybe.withDefault "" model.level0FilterString
                                , label = Input.labelLeft [] <| Element.text "Filter:"
                                , placeholder = Nothing
                                }
                            , overhangRadioRow model
                            , insertTable model
                            , Element.row [ centerX, spacing 50 ] [ customAddButton "+" (SwitchPage AddLevel0Page) ]
                            ]
                        )
                        model.level0AccordionStatus
                    ]
                ]
        ]
    }


addLevel0View : Model -> Document Msg
addLevel0View model =
    { title = "Add new Level 0 vector"
    , body =
        [ Element.layout [] <|
            row [ Element.height Element.fill ]
                [ navLinks
                , column [ padding 25, spacing 25 ]
                    [ el [ Element.Region.heading 1, Font.size 50 ] <| Element.text "Add new Level 0 donor vector"
                    , Input.text []
                        { label = Input.labelLeft [] <| Element.text "Name:\t"
                        , onChange = ChangeLevel0NameToAdd
                        , placeholder = Nothing
                        , text = model.nameLevel0ToAdd
                        }
                    , Input.text []
                        { label = Input.labelLeft [] <| Element.text "MP-G0-number:\tMP-G0- "
                        , onChange = ChangeLevel0MpgNumberToAdd
                        , placeholder = Nothing
                        , text = model.mpg0NumberLevel0ToAdd
                        }
                    , row []
                        [ el [] <| Element.text "Length (bp):\t"
                        , Element.html <|
                            Html.input
                                [ HA.type_ "number"
                                , HA.min "0"
                                , Html.Events.onInput ChangeLevel0LengthToAdd
                                , HA.value (String.fromInt model.lengthLevel0ToAdd)
                                , HA.style "padding" "10px"
                                ]
                                []
                        ]
                    , Input.radioRow [spacing 5, padding 10]
                        { label = Input.labelAbove [] <| Element.text "Overhang Type:\t"
                            , onChange = ChangeLevel0OverhangToAdd
                            , options =
                                makeOverhangOptions completeOverhangList
                            , selected = model.overhangLevel0ToAdd
                         }
                    , Element.html <| Html.button [ HA.style "margin" "50px", onClick GBNewLevel0Requested ] [ Html.text "Load Genbank file" ]
                    , Input.button
                        [ centerX
                        , Background.color color.blue
                        , padding 10
                        , Font.color color.white
                        , Border.width 3
                        , Border.solid
                        , Border.color color.darkCharcoal
                        , Border.rounded 25
                        ]
                        { label = Element.text "Add"
                        , onPress = Just (AddLevel0 { name = model.nameLevel0ToAdd, mPG0Number = "MP-G0-" ++ model.mpg0NumberLevel0ToAdd, overhang = model.overhangLevel0ToAdd, length = model.lengthLevel0ToAdd })
                        }
                    ]
                ]
        ]
    }

makeOverhangOptions overHangList =
    List.map2 Input.option overHangList (List.map Element.text (List.map showOverhang overHangList))

addBackboneView : Model -> Document Msg
addBackboneView model =
    { title = "Add new Backbone"
    , body =
        [ Element.layout [] <|
            row [ Element.height Element.fill ]
                [ navLinks
                , column [ centerX, Element.width Element.fill, spacing 25, padding 25 ]
                    [ el [ Element.Region.heading 1, Font.size 50 ] <| Element.text "Add new Backbone"
                    , Input.text []
                        { onChange = ChangeBackboneNameToAdd
                        , text = model.nameBackboneToAdd
                        , label = Input.labelLeft [] <| Element.text "Name:"
                        , placeholder = Nothing
                        }
                    , Input.text []
                        { onChange = ChangeBackboneMpgNumberToAdd
                        , text = model.mpgbNumberBackboneToAdd
                        , label = Input.labelLeft [] <| Element.text "MP-GB-number:\tMP-GB-"
                        , placeholder = Nothing
                        }
                    , row []
                        [ el [] <| Element.text "Choose a level:"
                        , Element.html <| Html.input [ HA.style "margin" "25px", HA.type_ "number", HA.min "0", HA.max "2", Html.Events.onInput ChangeBackboneLevelToAdd, HA.value (String.fromInt model.levelBackboneToAdd) ] []
                        ]
                    , row []
                        [ el [] <| Element.text "Length (bp):"
                        , Element.html <| Html.input [ HA.style "margin" "25px", HA.type_ "number", HA.min "1", Html.Events.onInput ChangeBackboneLengthToAdd, HA.value (String.fromInt model.lengthBackboneToAdd) ] []
                        ]
                    , Element.html <| Html.button [ HA.style "margin" "50px", onClick GbNewBackboneRequested ] [ Html.text "Load Genbank file" ]
                    , Input.button
                        [ centerX
                        , Background.color color.blue
                        , padding 10
                        , Font.color color.white
                        , Border.width 3
                        , Border.solid
                        , Border.color color.darkCharcoal
                        , Border.rounded 25
                        ]
                        { label = Element.text "Add"
                        , onPress = Just (AddBackbone { name = model.nameBackboneToAdd, mPGBNumber = "MP-GB-" ++ model.mpgbNumberBackboneToAdd, level = model.levelBackboneToAdd, length = model.lengthBackboneToAdd })
                        }
                    ]
                ]
        ]
    }


constructLevel2View : Model -> Document Msg
constructLevel2View model =
    { title = "Construct new Level 2 - Coming soon!"
    , body =
        [ Element.layout [] <|
            row [ Element.width Element.fill, Element.height Element.fill, centerX ] [ navLinks, Element.html <| Html.img [ HA.src "../img/under_construction.jpg" ] [] ]
        ]
    }


constructLevel1View : Model -> Document Msg
constructLevel1View model =
    { title = "Constructing a Level 1"
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
                , column [ spacing 25, Element.width Element.fill, centerX, padding 50 ]
                    [ Element.html <| mainView model
                    , el
                        [ Element.Region.heading 1
                        , Font.size 50
                        , Font.color color.darkCharcoal
                        ]
                      <|
                        Element.text "Level 1 construct design"
                    , el
                        [ Element.Region.heading 2
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


-- Visual Representation


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
            List.map showOverhang <| List.map (Maybe.withDefault Invalid) <| List.map .overhang model.selectedInserts

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

        descending : comparable -> comparable -> Order
        descending a b =
            case compare a b of
                LT ->
                    GT

                EQ ->
                    EQ

                GT ->
                    LT

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
    Html.div [ HA.style "width" "100%" ]
        [ svg [ HA.style "padding" "10px", HA.style "border" "solid 1px steelblue", HA.style "margin" "10px", HA.style "border-radius" "25px", viewBox 0 0 w h ]
            [ g [ transform [ Translate (w / 2) (h / 2) ] ]
                [ g [] <| List.indexedMap pieSlice pieData
                , g [] <| List.map2 pieLabel pieData data
                ]
            ]
        , Html.div [ HA.style "justify-content" "center", HA.style "align-items" "center", HA.style "display" "flex" ]
            [ Html.button [ onClick ResetInsertList, HA.style "margin-right" "75px", HA.style "padding" "10px", HA.style "background-color" "white", HA.style "border-radius" "6px", HA.style "border" "solid 3px rgb(152, 171, 198)" ] [ Html.text "Reset Insert List" ]
            , Html.button [ onClick ResetBackbone, HA.style "margin-left" "75px", HA.style "padding" "10px", HA.style "background-color" "white", HA.style "border-radius" "6px", HA.style "border" "solid 3px rgb(152, 171, 198)" ] [ Html.text "Reset All" ]
            ]
        ]



-- elements


navLinks : Element Msg
navLinks =
    column
        [ Background.color color.blue
        , Element.height Element.fill
        , padding 10
        , spacing 10
        ]
        [ Input.button
            [ Font.size 15
            , Font.color color.white
            , Element.width Element.fill
            , Font.underline
            , Font.bold
            ]
            { onPress = Just (SwitchPage Catalogue), label = Element.text "Home" }
        , Input.button
            [ Font.size 15
            , Font.color color.white
            , Element.width Element.fill
            , Font.underline
            , Font.bold
            ]
            { onPress = Just (SwitchPage Catalogue), label = Element.text "Vector Catalog" }
        , Input.button
            [ Font.size 15
            , Font.color color.white
            , Element.width Element.fill
            , Font.underline
            , Font.bold
            ]
            { onPress = Just (SwitchPage ConstructLevel1), label = Element.text "New Level 1 construct" }
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
            , el ((Element.width <| fillPortion 1) :: headerAttrs) <| Element.text "Overhang"
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
                -- { data = List.filter(filterLevel0 model.level0FilterString) <| model.insertList
                -- { data = List.filter(filterLevel0OnOverhang (showOverhang model.currOverhang) model.insertList
                { data = model.insertList |> List.filter (filterLevel0OnOverhang( Just model.currOverhang)) |> List.filter (filterLevel0 model.level0FilterString)
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
                    , { header = none
                      , width = fillPortion 1
                      , view = .overhang >> Maybe.withDefault Invalid >> showOverhang >> Element.text >> el [ centerY ]
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
            , el ((Element.width <| fillPortion 1) :: headerAttrs) <| Element.text "Level"
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
                { data = List.filter (filterBackbone model.backboneFilterString) model.backboneList
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
                    , { header = none
                      , width = fillPortion 1
                      , view = .level >> String.fromInt >> Element.text >> el [ centerY ]
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

        ChangeNumberInserts newNumber ->
            ( { model | numberInserts = newNumber }, Cmd.none )

        ChangeBackboneLevel newLevel ->
            ( { model | backboneLevel = newLevel }, Cmd.none )

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

        UrlChanged _ ->
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

        SwitchPage page ->
            ( { model | page = page }, Cmd.none )

        FilterBackboneTable filter ->
            ( { model | backboneFilterString = Just filter }, Cmd.none )

        FilterLevel0Table filter ->
            ( { model | level0FilterString = Just filter }, Cmd.none )

        FilterLevel1Table filter ->
            ( { model | level1FilterString = Just filter }, Cmd.none )

        BackboneAccordionToggled ->
            ( { model | backboneAccordionStatus = not model.backboneAccordionStatus }, Cmd.none )

        Level0AccordionToggled ->
            ( { model | level0AccordionStatus = not model.level0AccordionStatus }, Cmd.none )

        Level1AccordionToggled ->
            ( { model | level1AccordionStatus = not model.level1AccordionStatus }, Cmd.none )

        ToggleAll ->
            ( { model
                | backboneAccordionStatus = not model.backboneAccordionStatus
                , level0AccordionStatus = not model.level0AccordionStatus
                , level1AccordionStatus = not model.level1AccordionStatus
              }
            , Cmd.none
            )

        AddBackbone newBB ->
            ( { model | backboneList = newBB :: model.backboneList }, Cmd.none )

        ChangeBackboneNameToAdd name ->
            ( { model | nameBackboneToAdd = name }, Cmd.none )

        ChangeBackboneMpgNumberToAdd mpgbNumber ->
            ( { model | mpgbNumberBackboneToAdd = mpgbNumber }, Cmd.none )

        ChangeBackboneLevelToAdd lvl_str ->
            ( { model | levelBackboneToAdd = lvl_str |> String.toInt |> Maybe.withDefault model.levelBackboneToAdd }, Cmd.none )

        ChangeBackboneLengthToAdd len_str ->
            ( { model | lengthBackboneToAdd = len_str |> String.toInt |> Maybe.withDefault model.lengthBackboneToAdd }, Cmd.none )

        GbNewBackboneRequested ->
            ( model, Select.file [ "text" ] GbNewBackboneSelected )

        GbNewBackboneSelected file ->
            ( model, Task.perform GbNewBackboneLoaded (File.toString file) )

        GbNewBackboneLoaded content ->
            ( { model | backboneGenbankContent = Just <| Debug.log "Genbank Content:" content }, Cmd.none )

        AddLevel0 newIns ->
            ( { model | insertList = newIns :: model.insertList }, Cmd.none )

        ChangeLevel0NameToAdd name ->
            ( { model | nameLevel0ToAdd = name }, Cmd.none )

        ChangeLevel0MpgNumberToAdd mpg0Number ->
            ( { model | mpg0NumberLevel0ToAdd = mpg0Number }, Cmd.none )

        ChangeLevel0OverhangToAdd overhang ->
            ( { model | overhangLevel0ToAdd = Just overhang }, Cmd.none )

        ChangeLevel0LengthToAdd len_str ->
            ( { model | lengthLevel0ToAdd = len_str |> String.toInt |> Maybe.withDefault model.lengthLevel0ToAdd }, Cmd.none )

        GBNewLevel0Requested ->
            ( model, Select.file [ "text" ] GBNewLevel0Selected )

        GBNewLevel0Selected file ->
            ( model, Task.perform GbNewLevel0Loaded (File.toString file) )

        GbNewLevel0Loaded content ->
            ( { model | level0GenbankContent = Just <| Debug.log "Genbank Content:" content }, Cmd.none )


addInsert =
    Nothing



-- Filter functions


filterBackbone : Maybe String -> Backbone -> Bool
filterBackbone needle val =
    case needle of
        Nothing ->
            True

        Just ndle ->
            String.contains ndle val.name || String.contains ndle val.mPGBNumber


filterLevel0 needle val =
    case needle of
        Nothing ->
            True

        Just ndle ->
            String.contains ndle val.name || String.contains ndle val.mPG0Number


filterLevel0OnOverhang needle val =
    needle == val.overhang



-- End Filter functions


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
        , onUrlChange = UrlChanged
        }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
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

        _ ->
            ""


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


testInsertList : Overhang -> List Insert
testInsertList overhang =
    [ { name = "Insert A1", mPG0Number = "MG-G0-000001", overhang = Just A__B, length = 952 }
    , { name = "Insert A2", mPG0Number = "MG-G0-000002", overhang = Just A__B, length = 1526 }
    , { name = "Insert A3", mPG0Number = "MG-G0-000003", overhang = Just A__B, length = 1874 }
    , { name = "Insert A4", mPG0Number = "MG-G0-000004", overhang = Just A__B, length = 2698 }
    , { name = "Insert A5", mPG0Number = "MG-G0-000005", overhang = Just A__B, length = 528 }
    , { name = "Insert A6", mPG0Number = "MG-G0-000006", overhang = Just A__B, length = 865 }
    , { name = "Insert A7", mPG0Number = "MG-G0-000007", overhang = Just A__B, length = 1058 }
    , { name = "Insert B1", mPG0Number = "MG-G0-000008", overhang = Just B__C, length = 952 }
    , { name = "Insert B2", mPG0Number = "MG-G0-000009", overhang = Just B__C, length = 1526 }
    , { name = "Insert B3", mPG0Number = "MG-G0-000010", overhang = Just B__C, length = 1874 }
    , { name = "Insert B4", mPG0Number = "MG-G0-000011", overhang = Just B__C, length = 2698 }
    , { name = "Insert B5", mPG0Number = "MG-G0-000012", overhang = Just B__C, length = 528 }
    , { name = "Insert B6", mPG0Number = "MG-G0-000013", overhang = Just B__C, length = 865 }
    , { name = "Insert B7", mPG0Number = "MG-G0-000014", overhang = Just B__C, length = 1058 }
    , { name = "Insert C1", mPG0Number = "MG-G0-000015", overhang = Just C__D, length = 952 }
    , { name = "Insert C2", mPG0Number = "MG-G0-000016", overhang = Just C__D, length = 1526 }
    , { name = "Insert C3", mPG0Number = "MG-G0-000017", overhang = Just C__D, length = 1874 }
    , { name = "Insert C4", mPG0Number = "MG-G0-000018", overhang = Just C__D, length = 2698 }
    , { name = "Insert C5", mPG0Number = "MG-G0-000019", overhang = Just C__D, length = 528 }
    , { name = "Insert C6", mPG0Number = "MG-G0-000020", overhang = Just C__D, length = 865 }
    , { name = "Insert C7", mPG0Number = "MG-G0-000021", overhang = Just C__D, length = 1058 }
    , { name = "Insert D1", mPG0Number = "MG-G0-000022", overhang = Just C__G, length = 952 }
    , { name = "Insert D2", mPG0Number = "MG-G0-000023", overhang = Just C__G, length = 1526 }
    , { name = "Insert D3", mPG0Number = "MG-G0-000024", overhang = Just C__G, length = 1874 }
    , { name = "Insert D4", mPG0Number = "MG-G0-000025", overhang = Just C__G, length = 2698 }
    , { name = "Insert D5", mPG0Number = "MG-G0-000026", overhang = Just C__G, length = 528 }
    , { name = "Insert D6", mPG0Number = "MG-G0-000027", overhang = Just C__G, length = 865 }
    , { name = "Insert D7", mPG0Number = "MG-G0-000028", overhang = Just C__G, length = 1058 }
    , { name = "Insert E1", mPG0Number = "MG-G0-000029", overhang = Just D__E, length = 952 }
    , { name = "Insert E2", mPG0Number = "MG-G0-000030", overhang = Just D__E, length = 1526 }
    , { name = "Insert E3", mPG0Number = "MG-G0-000031", overhang = Just D__E, length = 1874 }
    , { name = "Insert E4", mPG0Number = "MG-G0-000032", overhang = Just D__E, length = 2698 }
    , { name = "Insert E5", mPG0Number = "MG-G0-000033", overhang = Just D__E, length = 528 }
    , { name = "Insert E6", mPG0Number = "MG-G0-000034", overhang = Just D__E, length = 865 }
    , { name = "Insert E7", mPG0Number = "MG-G0-000035", overhang = Just D__E, length = 1058 }
    , { name = "Insert F1", mPG0Number = "MG-G0-000036", overhang = Just D__G, length = 952 }
    , { name = "Insert F2", mPG0Number = "MG-G0-000037", overhang = Just D__G, length = 1526 }
    , { name = "Insert F3", mPG0Number = "MG-G0-000038", overhang = Just D__G, length = 1874 }
    , { name = "Insert F4", mPG0Number = "MG-G0-000039", overhang = Just D__G, length = 2698 }
    , { name = "Insert F5", mPG0Number = "MG-G0-000040", overhang = Just D__G, length = 528 }
    , { name = "Insert F6", mPG0Number = "MG-G0-000041", overhang = Just D__G, length = 865 }
    , { name = "Insert F7", mPG0Number = "MG-G0-000042", overhang = Just D__G, length = 1058 }
    , { name = "Insert G1", mPG0Number = "MG-G0-000043", overhang = Just E__F, length = 952 }
    , { name = "Insert G2", mPG0Number = "MG-G0-000044", overhang = Just E__F, length = 1526 }
    , { name = "Insert G3", mPG0Number = "MG-G0-000045", overhang = Just E__F, length = 1874 }
    , { name = "Insert G4", mPG0Number = "MG-G0-000046", overhang = Just E__F, length = 2698 }
    , { name = "Insert G5", mPG0Number = "MG-G0-000047", overhang = Just E__F, length = 528 }
    , { name = "Insert G6", mPG0Number = "MG-G0-000048", overhang = Just E__F, length = 865 }
    , { name = "Insert G7", mPG0Number = "MG-G0-000049", overhang = Just E__F, length = 1058 }
    , { name = "Insert H1", mPG0Number = "MG-G0-000050", overhang = Just E__G, length = 952 }
    , { name = "Insert H2", mPG0Number = "MG-G0-000051", overhang = Just E__G, length = 1526 }
    , { name = "Insert H3", mPG0Number = "MG-G0-000052", overhang = Just E__G, length = 1874 }
    , { name = "Insert H4", mPG0Number = "MG-G0-000053", overhang = Just E__G, length = 2698 }
    , { name = "Insert H5", mPG0Number = "MG-G0-000054", overhang = Just E__G, length = 528 }
    , { name = "Insert H6", mPG0Number = "MG-G0-000055", overhang = Just E__G, length = 865 }
    , { name = "Insert H7", mPG0Number = "MG-G0-000056", overhang = Just E__G, length = 1058 }
    , { name = "Insert I1", mPG0Number = "MG-G0-000057", overhang = Just F__G, length = 952 }
    , { name = "Insert I2", mPG0Number = "MG-G0-000058", overhang = Just F__G, length = 1526 }
    , { name = "Insert I3", mPG0Number = "MG-G0-000059", overhang = Just F__G, length = 1874 }
    , { name = "Insert I4", mPG0Number = "MG-G0-000060", overhang = Just F__G, length = 2698 }
    , { name = "Insert I5", mPG0Number = "MG-G0-000061", overhang = Just F__G, length = 528 }
    , { name = "Insert I6", mPG0Number = "MG-G0-000062", overhang = Just F__G, length = 865 }
    , { name = "Insert I7", mPG0Number = "MG-G0-000063", overhang = Just F__G, length = 1058 }
    ]


testBackboneList : Int -> List Backbone
testBackboneList bbLevel =
    [ { name = "Backbone L0-1", mPGBNumber = "MP-GB-000001", level = 0, length = 10520 }
    , { name = "Backbone L0-2", mPGBNumber = "MP-GB-000002", level = 0, length = 11840 }
    , { name = "Backbone L0-3", mPGBNumber = "MP-GB-000003", level = 0, length = 9520 }
    , { name = "Backbone L0-4", mPGBNumber = "MP-GB-000004", level = 0, length = 13258 }
    , { name = "Backbone L0-5", mPGBNumber = "MP-GB-000005", level = 0, length = 11470 }
    , { name = "Backbone L0-6", mPGBNumber = "MP-GB-000006", level = 0, length = 13690 }
    , { name = "Backbone L0-7", mPGBNumber = "MP-GB-000007", level = 0, length = 12580 }
    , { name = "Backbone L1-1", mPGBNumber = "MP-GB-000011", level = 1, length = 10520 }
    , { name = "Backbone L1-2", mPGBNumber = "MP-GB-000012", level = 1, length = 11840 }
    , { name = "Backbone L1-3", mPGBNumber = "MP-GB-000013", level = 1, length = 9520 }
    , { name = "Backbone L1-4", mPGBNumber = "MP-GB-000014", level = 1, length = 13258 }
    , { name = "Backbone L1-5", mPGBNumber = "MP-GB-000015", level = 1, length = 11470 }
    , { name = "Backbone L1-6", mPGBNumber = "MP-GB-000016", level = 1, length = 13690 }
    , { name = "Backbone L1-7", mPGBNumber = "MP-GB-000017", level = 1, length = 12580 }
    , { name = "Backbone L2-1", mPGBNumber = "MP-GB-000021", level = 2, length = 10520 }
    , { name = "Backbone L2-2", mPGBNumber = "MP-GB-000022", level = 2, length = 11840 }
    , { name = "Backbone L2-3", mPGBNumber = "MP-GB-000023", level = 2, length = 9520 }
    , { name = "Backbone L2-4", mPGBNumber = "MP-GB-000024", level = 2, length = 13258 }
    , { name = "Backbone L2-5", mPGBNumber = "MP-GB-000025", level = 2, length = 11470 }
    , { name = "Backbone L2-6", mPGBNumber = "MP-GB-000026", level = 2, length = 13690 }
    , { name = "Backbone L2-7", mPGBNumber = "MP-GB-000027", level = 2, length = 12580 }
    ]
