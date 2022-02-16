module Main exposing (..)

import Accordion
import Array exposing (Array)
import Auth
    exposing
        ( Auth(..)
        , AuthCode
        , Login
        , User
        , authCode
        , authDecoder
        , authRequestDecoder
        )
import Browser exposing (Document)
import Browser.Dom exposing (Error(..))
import Browser.Navigation as Nav
import Color
import Dict
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border exposing (rounded)
import Element.Events as EE
import Element.Font as Font
import Element.Input as Input
import Element.Region
import Html exposing (Html, a)
import Html.Attributes as HA
import Html.Events exposing (onClick)
import Http exposing (Error(..), expectJson, jsonBody)
import Interface exposing (button_, link_, title, viewMaybe)
import Json.Decode as Decode
import Json.Encode as Encode
import List
import List.Extra
import Molecules exposing (..)
import Path
import Shape exposing (defaultPieConfig)
import String
import Task
import TypedSvg exposing (g, svg, text_)
import TypedSvg.Attributes exposing (dy, stroke, textAnchor, transform, viewBox, x)
import TypedSvg.Core exposing (Svg)
import TypedSvg.Types exposing (AnchorAlignment(..), Paint(..), Transform(..), em)
import UINotification as Notify
import Url exposing (Url)


type DisplayPage
    = LoginPage
    | Catalogue
    | ConstructLevel1
    | AddLevel0Page
    | AddBackbonePage



-- Model


type alias Model =
    { page : DisplayPage
    , currApp : Application
    , currOverhang : Bsa1Overhang
    , backboneLevel : Int
    , constructName : String
    , constructNumber : String
    , constructLength : Int
    , applicationNote : String
    , description : String
    , selectedInserts : List Level0
    , selectedBackbone : Maybe Backbone
    , auth : Auth
    , notifications : Notify.Notifications
    , key : Nav.Key

    -- Attributes for the vector catalog
    , backboneFilterString : Maybe String
    , level0FilterString : Maybe String
    , level1FilterString : Maybe String
    , backboneAccordionStatus : Bool
    , level0AccordionStatus : Bool
    , level1AccordionStatus : Bool
    , backboneList : List Backbone
    , insertList : List Level0

    -- Attributes for adding backbones
    , backboneToAdd : Maybe Backbone

    -- Attributes for adding Level0
    , level0ToAdd : Maybe Level0
    }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        model : Model
        model =
            { page = LoginPage
            , currApp = Standard
            , currOverhang = A__B
            , backboneLevel = 1

            -- Level1 fields
            , constructName = ""
            , constructNumber = ""
            , constructLength = 0
            , applicationNote = ""
            , description = ""
            , selectedInserts = []
            , selectedBackbone = Nothing

            -- |
            , auth = NotAuthenticated []
            , notifications = Notify.init
            , key = key
            , backboneFilterString = Nothing
            , level0FilterString = Nothing
            , level1FilterString = Nothing
            , backboneAccordionStatus = False
            , level0AccordionStatus = False
            , level1AccordionStatus = False
            , backboneList = []
            , insertList = []

            -- Backbone To Add attributes
            , backboneToAdd = Nothing

            -- Level0 To Add Attributes
            , level0ToAdd = Nothing
            }
    in
    ( model, router url model )


type Application
    = Standard
    | Five
    | Four
    | Three


type Msg
    = -- Level 1 construction Msg
      ChooseApplication Application
    | ChangeOverhang Bsa1Overhang
    | ChangeConstructName String
    | ChangeConstructNumber String
    | ChangeApplicationNote String
    | ChangeDescription String
    | AppendInsert Level0
    | ChangeBackbone Backbone
    | ResetInsertList
    | ResetAll
      -- Login Msg
    | GotLoginUrls (Result Http.Error Auth)
    | GotAuthentication (Result Http.Error Auth)
    | UrlChanged Url
    | LinkClicked Browser.UrlRequest
      -- Msg Switching pages
    | SwitchPage DisplayPage
      -- Vector catalogue Msg
    | BackboneAccordionToggled -- TODO: Unify these 3
    | Level0AccordionToggled
    | ToggleAll
    | FilterBackboneTable String -- TODO: Unify
    | FilterLevel0Table String
      -- Msg for adding Backbones
    | AddBackbone Backbone
    | ChangeBackboneToAdd ChangeMol
      -- Msg for adding Level 0
    | AddLevel0 Level0
    | ChangeLevel0ToAdd ChangeMol
      -- Msg for retrieving Vectors
    | RequestAllLevel0
    | Level0Received (Result Http.Error (List Level0))
    | RequestAllBackbones
    | BackbonesReceived (Result Http.Error (List Backbone))
      -- Notifications
    | CloseNotification Int



-- view


view : Model -> Document Msg
view model =
    { title = "Golden Gateway"
    , body =
        [ Element.layout
            [ Element.height Element.fill
            , inFront <| Notify.view CloseNotification model.notifications
            , inFront navLinks
            ]
            (row
                [ Element.width Element.fill
                , Element.height Element.fill
                ]
                [ navLinks
                , case model.page of
                    LoginPage ->
                        loginView model

                    ConstructLevel1 ->
                        constructLevel1View model

                    Catalogue ->
                        catalogueView model

                    AddLevel0Page ->
                        addLevel0View model

                    AddBackbonePage ->
                        addBackboneView model
                ]
            )
        ]
    }


catalogueView : Model -> Element Msg
catalogueView model =
    column
        [ Element.width Element.fill
        , Element.height Element.fill
        , spacing 25
        , padding 50
        , centerX
        ]
        [ title "Vector Catalog"
        , row [ spacing 20 ]
            [ button_ ToggleAll "Toggle all"
            , button_ RequestAllLevel0 "Populate Level 0 table from DB"
            , button_ RequestAllBackbones "Populate Backbone table from DB"
            ]
        , Accordion.accordion
            (Accordion.head
                [ EE.onClick BackboneAccordionToggled
                , Background.color color.blue
                , padding 25
                , Border.solid
                , Border.rounded 6
                ]
                [ Element.text "Backbones"
                ]
            )
            (Accordion.body [ padding 25 ]
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
                , alignLeft
                ]
                [ Element.text "Level 0"
                ]
            )
            (Accordion.body [ padding 25 ]
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


addLevel0View : Model -> Element Msg
addLevel0View model =
    column [ Element.height Element.fill, padding 25, spacing 25 ]
        [ el [ Element.Region.heading 1, Font.size 50 ] <| Element.text "Add new Level 0 donor vector"
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Name:\t"
            , onChange = ChangeName >> ChangeLevel0ToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map .name model.level0ToAdd
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "MP-G0-number:\tMP-G0- "
            , onChange = ChangeMPG >> ChangeLevel0ToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map (.mPGNumber >> String.fromInt) model.level0ToAdd
            }
        , Input.radioRow [ spacing 5, padding 10 ]
            { label = Input.labelAbove [] <| Element.text "Overhang Type:\t"
            , onChange = ChangeBsa1 >> ChangeLevel0ToAdd
            , options =
                makeOverhangOptions allOverhangs
            , selected = Maybe.map .bsa1Overhang model.level0ToAdd
            }
        , Element.html <|
            Html.button
                [ HA.style "margin" "50px" ]
                [ Html.text "Load Genbank file" ]
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
            , onPress = Maybe.map AddLevel0 model.level0ToAdd
            }
        ]


makeOverhangOptions : List Bsa1Overhang -> List (Input.Option Bsa1Overhang msg)
makeOverhangOptions overHangList =
    List.map (\ohang -> Input.option ohang (showBsa1Overhang ohang |> Element.text)) overHangList


addBackboneView : Model -> Element Msg
addBackboneView model =
    column [ Element.height Element.fill, centerX, Element.width Element.fill, spacing 25, padding 25 ]
        [ el [ Element.Region.heading 1, Font.size 50 ] <| Element.text "Add new Backbone"
        , Input.text []
            { onChange = ChangeName >> ChangeBackboneToAdd
            , text = Maybe.withDefault "" <| Maybe.map .name model.backboneToAdd
            , label = Input.labelLeft [] <| Element.text "Name:"
            , placeholder = Nothing
            }
        , Input.text []
            { onChange = ChangeMPG >> ChangeBackboneToAdd
            , text = Maybe.withDefault "" <| Maybe.map (.mPGNumber >> String.fromInt) model.backboneToAdd
            , label = Input.labelLeft [] <| Element.text "MP-GB-number:\tMP-GB-"
            , placeholder = Nothing
            }
        , Element.html <|
            Html.button
                [ HA.style "margin" "50px" ]
                [ Html.text "Load Genbank file" ]
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
            , onPress = Maybe.map AddBackbone model.backboneToAdd
            }
        ]


constructLevel2View : Model -> Element Msg
constructLevel2View _ =
    row
        [ Element.width Element.fill, Element.height Element.fill, centerX ]
        [ navLinks, Element.html <| Html.img [ HA.src "../img/under_construction.jpg" ] [] ]


constructLevel1View : Model -> Element Msg
constructLevel1View model =
    column [ Element.height Element.fill, spacing 25, Element.width Element.fill, centerX, padding 50 ]
        [ el
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


loginView : Model -> Element Msg
loginView model =
    column
        [ Element.width Element.fill
        , Element.height Element.fill
        ]
    <|
        case model.auth of
            Authenticated user ->
                [ Element.text ("Welcome " ++ Maybe.withDefault "No user name" user.name)
                ]

            NotAuthenticated urls ->
                viewLoginForm urls


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
                    (Element.text "Login with:")
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


viewLoginUrls : List Login -> List (Html Msg)
viewLoginUrls loginUrls =
    case loginUrls of
        [] ->
            [ Html.text "Fetching..." ]

        _ ->
            List.map (\lgn -> a [ HA.href lgn.url ] [ Html.text lgn.name ]) loginUrls


customAddButton : String -> Msg -> Element Msg
customAddButton buttonText msg =
    Input.button
        [ centerX
        , Background.color color.blue
        , Font.color color.white
        , padding 25
        , Border.width 3
        , Border.solid
        , Border.color color.darkCharcoal
        , Border.rounded 100
        ]
        { label = Element.text buttonText
        , onPress = Just msg
        }



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


tupleToRecord : ( String, String, Int ) -> { name : String, bsa1_overhang : String, length : Int }
tupleToRecord ( t_name, t_overhang, t_length ) =
    { name = t_name, bsa1_overhang = t_overhang, length = t_length }


visualRepresentation : Model -> Html Msg
visualRepresentation model =
    let
        -- Note: The reversing is for making sure Level0 1 is at position 0. This way the destination vector is appended on the back of the list!
        insertOverhangs =
            List.map showBsa1Overhang <| List.map .bsa1Overhang model.selectedInserts

        insertNames =
            List.map .name model.selectedInserts

        insertLengths =
            List.map (String.length << .sequence) model.selectedInserts

        insertTuple =
            List.Extra.zip3 insertNames insertOverhangs insertLengths

        insertRecordList =
            List.map tupleToRecord insertTuple

        sortedInsertRecordList =
            List.sortBy .bsa1_overhang insertRecordList

        chartLabels =
            (Maybe.withDefault "" <| Maybe.map .name model.selectedBackbone) :: List.map .name sortedInsertRecordList

        chartLengths =
            List.reverse
                (List.map toFloat <|
                    String.length (Maybe.withDefault "" <| Maybe.map .sequence model.selectedBackbone)
                        :: List.reverse (List.map .length sortedInsertRecordList)
                )

        data =
            List.map2 Tuple.pair chartLabels chartLengths

        pieData =
            data |> List.map Tuple.second |> Shape.pie { defaultPieConfig | outerRadius = radius, innerRadius = 0.9 * radius, sortingFn = \_ _ -> EQ }

        -- sortingFn sets the sorting function -> default = sorting by value (inserts length in this case)
    in
    Html.div [ HA.style "width" "100%" ]
        [ svg
            [ HA.style "padding" "10px"
            , HA.style "border" "solid 1px steelblue"
            , HA.style "margin" "10px"
            , HA.style "border-radius" "25px"
            , viewBox 0 0 w h
            ]
            [ g [ transform [ Translate (w / 2) (h / 2) ] ]
                [ g [] <| List.indexedMap pieSlice pieData
                , g [] <| List.map2 pieLabel pieData data
                ]
            ]
        , Html.div [ HA.style "justify-content" "center", HA.style "align-items" "center", HA.style "display" "flex" ]
            [ Html.button
                [ onClick ResetInsertList
                , HA.style "margin-right" "75px"
                , HA.style "padding" "10px"
                , HA.style "background-color" "white"
                , HA.style "border-radius" "6px"
                , HA.style "border" "solid 3px rgb(152, 171, 198)"
                ]
                [ Html.text "Reset Level0 List" ]
            , Html.button
                [ onClick ResetAll
                , HA.style "margin-left" "75px"
                , HA.style "padding" "10px"
                , HA.style "background-color" "white"
                , HA.style "border-radius" "6px"
                , HA.style "border" "solid 3px rgb(152, 171, 198)"
                ]
                [ Html.text "Reset All" ]
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
        [ link_ (SwitchPage Catalogue) "Home"
        , link_ (SwitchPage Catalogue) "Vector Catalogue"
        , link_ (SwitchPage ConstructLevel1) "New Level1 construct"
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
        makeButton : Bsa1Overhang -> Input.Option Bsa1Overhang Msg
        makeButton bsa1_overhang =
            showBsa1Overhang bsa1_overhang
                |> button
                |> Input.optionWith bsa1_overhang
    in
    Input.radioRow
        []
        { onChange = ChangeOverhang
        , selected = Just model.currOverhang
        , label =
            Input.labelAbove
                [ paddingEach { bottom = 20, top = 0, left = 0, right = 0 } ]
            <|
                Element.text "Choose Overhang type"
        , options = List.map makeButton <| overhangShape model.currApp
        }


button : String -> Input.OptionState -> Element msg
button label state =
    el
        [ paddingEach { left = 20, right = 20, top = 10, bottom = 10 }
        , Border.color color.blue
        , Background.color <|
            if state == Input.Selected then
                color.lightBlue

            else
                color.white
        ]
        (el [ centerX, centerY ] (Element.text label))


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
            , el ((Element.width <| fillPortion 5) :: headerAttrs) <| Element.text "Level0 Name"
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
                { data =
                    model.insertList
                        |> List.filter (filterLevel0OnOverhang model.currOverhang)
                        |> List.filter (filterMolecule model.level0FilterString)
                , columns =
                    [ { header = none
                      , width = fillPortion 3
                      , view = .mPGNumber >> String.fromInt >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 5
                      , view =
                            \level0 ->
                                Input.button [ Font.color color.blue, Font.bold, Font.underline ]
                                    { onPress = Just (AppendInsert level0)
                                    , label = Element.text level0.name
                                    }
                      }
                    , { header = none
                      , width = fillPortion 1
                      , view = .sequence >> String.length >> String.fromInt >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 1
                      , view = .bsa1Overhang >> Just >> viewMaybe showBsa1Overhang
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
            , padding 40
            ]
            [ el ((Element.width <| fillPortion 3) :: headerAttrs) <| Element.text "MP-GB-Number"
            , el ((Element.width <| fillPortion 5) :: headerAttrs) <| Element.text "Backbone Name"
            , el ((Element.width <| fillPortion 1) :: headerAttrs) <| Element.text "Length"
            , el ((Element.width <| fillPortion 3) :: headerAttrs) <| Element.text "bsa1 Overhang"
            , el ((Element.width <| fillPortion 3) :: headerAttrs) <| Element.text "bsmb1 Overhang"
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
                , spacing 20
                , padding 15
                ]
                { data = List.filter (filterMolecule model.backboneFilterString) model.backboneList
                , columns =
                    [ { header = none
                      , width = fillPortion 3
                      , view = .mPGNumber >> String.fromInt >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 5
                      , view =
                            \backbone ->
                                Input.button [ Font.color color.blue, Font.bold, Font.underline ]
                                    { onPress = Just (ChangeBackbone backbone)
                                    , label = Element.text backbone.name
                                    }
                      }
                    , { header = none
                      , width = fillPortion 1
                      , view = .sequence >> String.length >> String.fromInt >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 3
                      , view = .bsa1Overhang >> viewMaybe showBsa1Overhang
                      }
                    , { header = none
                      , width = fillPortion 3
                      , view = .bsmb1Overhang >> viewMaybe showBsmb1Overhang
                      }
                    ]
                }
        ]



-- update


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


overhangShape : Application -> List Bsa1Overhang
overhangShape app =
    let
        default : List Bsa1Overhang
        default =
            [ A__B, B__C, C__D, D__E, E__F, F__G ]
    in
    (case app of
        Standard ->
            Dict.get 6 overhangs

        Five ->
            Dict.get 5 overhangs

        Four ->
            Dict.get 4 overhangs

        Three ->
            Dict.get 3 overhangs
    )
        |> Maybe.withDefault default


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ChangeOverhang newOverhang ->
            ( { model | currOverhang = newOverhang }, Cmd.none )

        ChooseApplication newApp ->
            ( { model | currApp = newApp }, Cmd.none )

        ChangeConstructName newName ->
            ( { model | constructName = newName }, Cmd.none )

        ChangeConstructNumber newNumber ->
            ( { model | constructNumber = newNumber }, Cmd.none )

        ChangeApplicationNote newAN ->
            ( { model | applicationNote = newAN }, Cmd.none )

        ChangeDescription newDescription ->
            ( { model | description = newDescription }, Cmd.none )

        AppendInsert newInsert ->
            if not (List.member newInsert.bsa1Overhang (List.map .bsa1Overhang model.selectedInserts)) then
                ( { model
                    | selectedInserts = List.append model.selectedInserts [ newInsert ]
                    , constructLength =
                        List.sum
                            (String.length
                                (Maybe.withDefault "" <|
                                    Maybe.map .sequence model.selectedBackbone
                                )
                                :: String.length newInsert.sequence
                                :: List.map (.sequence >> String.length) model.selectedInserts
                            )
                  }
                , Cmd.none
                )

            else
                ( { model
                    | selectedInserts =
                        newInsert
                            :: List.filter
                                (\level0 ->
                                    not (level0.bsa1Overhang == newInsert.bsa1Overhang)
                                )
                                model.selectedInserts
                    , constructLength =
                        List.sum
                            (String.length
                                (Maybe.withDefault "" <|
                                    Maybe.map .sequence model.selectedBackbone
                                )
                                :: List.map (.sequence >> String.length)
                                    (newInsert
                                        :: List.filter
                                            (\level0 ->
                                                not (level0.bsa1Overhang == newInsert.bsa1Overhang)
                                            )
                                            model.selectedInserts
                                    )
                            )
                  }
                , Cmd.none
                )

        ChangeBackbone newBackbone ->
            ( { model
                | selectedBackbone = Just newBackbone
                , constructLength =
                    List.sum
                        (String.length newBackbone.sequence
                            :: List.map (.sequence >> String.length) model.selectedInserts
                        )
              }
            , Cmd.none
            )

        ResetInsertList ->
            ( { model
                | selectedInserts = []
                , constructLength =
                    String.length
                        (Maybe.withDefault "" <|
                            Maybe.map .sequence model.selectedBackbone
                        )
              }
            , Cmd.none
            )

        ResetAll ->
            ( { model
                | selectedInserts = []
                , selectedBackbone = Nothing
                , constructLength = 0
              }
            , Cmd.none
            )

        UrlChanged url ->
            ( model, router url model )

        GotLoginUrls res ->
            case res of
                Ok auth ->
                    ( { model | auth = auth }, Cmd.none )

                Err err ->
                    ( { model
                        | notifications = Notify.makeError "Fetching logins" (showHttpError err) model.notifications
                      }
                    , Cmd.none
                    )

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
                Ok auth ->
                    ( { model | auth = auth }
                    , Cmd.batch [ navToRoot, Task.succeed Catalogue |> Task.perform SwitchPage ]
                    )

                Err err ->
                    ( { model
                        | notifications = Notify.makeError "Logging in" (showHttpError err) model.notifications
                      }
                    , navToRoot
                    )

        SwitchPage page ->
            ( { model | page = page }, Cmd.none )

        FilterBackboneTable filter ->
            ( { model | backboneFilterString = Just filter }, Cmd.none )

        FilterLevel0Table filter ->
            ( { model | level0FilterString = Just filter }, Cmd.none )

        BackboneAccordionToggled ->
            ( { model | backboneAccordionStatus = not model.backboneAccordionStatus }, Cmd.none )

        Level0AccordionToggled ->
            ( { model | level0AccordionStatus = not model.level0AccordionStatus }, Cmd.none )

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

        ChangeBackboneToAdd change ->
            ( { model
                | backboneToAdd =
                    Maybe.withDefault initBackbone model.backboneToAdd
                        |> interpretBackboneChange change
                        |> Just
              }
            , Cmd.none
            )

        AddLevel0 newIns ->
            ( { model | insertList = newIns :: model.insertList }, Cmd.none )

        ChangeLevel0ToAdd change ->
            ( { model
                | level0ToAdd =
                    Maybe.withDefault initLevel0 model.level0ToAdd
                        |> interpretLevel0Change change
                        |> Just
              }
            , Cmd.none
            )

        Level0Received (Ok level0s) ->
            ( { model | insertList = level0s }, Cmd.none )

        Level0Received (Err _) ->
            ( model, Cmd.none )

        RequestAllLevel0 ->
            case model.auth of
                Authenticated user ->
                    ( model
                    , authenticatedGet user.token
                        "http://localhost:8000/vectors/level0"
                        Level0Received
                        (Decode.list level0Decoder)
                    )

                _ ->
                    ( { model
                        | notifications =
                            Notify.makeWarning "Not logged in" "" model.notifications
                      }
                    , Cmd.none
                    )

        CloseNotification which ->
            ( { model | notifications = Notify.close which model.notifications }
            , Cmd.none
            )

        BackbonesReceived (Ok backbones) ->
            ( { model | backboneList = backbones }, Cmd.none )

        BackbonesReceived (Err _) ->
            ( model, Cmd.none )

        RequestAllBackbones ->
            case model.auth of
                Authenticated user ->
                    ( model
                    , authenticatedGet user.token
                        "http://localhost:8000/vectors/backbones"
                        BackbonesReceived
                        (Decode.list backboneDecoder)
                    )

                _ ->
                    ( { model
                        | notifications =
                            Notify.makeWarning "Not logged in" "" model.notifications
                      }
                    , Cmd.none
                    )



-- Filter functions


filterMolecule : Maybe String -> { a | name : String, mPGNumber : String } -> Bool
filterMolecule needle val =
    case needle of
        Nothing ->
            True

        Just ndle ->
            String.contains ndle val.name
                || String.contains ndle (String.fromInt val.mPGNumber)


filterLevel0OnOverhang : Bsa1Overhang -> Level0 -> Bool
filterLevel0OnOverhang needle val =
    needle == val.bsa1Overhang



-- HTTP API


authenticatedGet : String -> String -> (Result Http.Error a -> Msg) -> Decode.Decoder a -> Cmd Msg
authenticatedGet token url msg decoder =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" ("Bearer " ++ token) ]
        , url = url
        , body = Http.emptyBody
        , expect = Http.expectJson msg decoder
        , timeout = Nothing
        , tracker = Nothing
        }


getLoginUrls : Cmd Msg
getLoginUrls =
    Http.get
        { url = "http://localhost:8000/login"
        , expect = expectJson GotLoginUrls authDecoder
        }


getAuthentication : AuthCode -> Cmd Msg
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
        , expect = expectJson GotAuthentication authDecoder
        }



-- ROUTING


router : Url -> { a | auth : Auth, key : Nav.Key } -> Cmd Msg
router url model =
    case ( url.path, model.auth ) of
        ( "/oidc_login", _ ) ->
            authCode url
                |> Maybe.map getAuthentication
                |> Maybe.withDefault Cmd.none

        ( "/login", NotAuthenticated _ ) ->
            getLoginUrls

        ( "/login", _ ) ->
            Nav.pushUrl model.key "/"

        ( _, NotAuthenticated _ ) ->
            Nav.pushUrl model.key "login"

        _ ->
            Cmd.none



-- MAIN


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }


color : { blue : Element.Color, darkCharcoal : Element.Color, lightBlue : Element.Color, lightGrey : Element.Color, white : Element.Color }
color =
    { blue = Element.rgb255 152 171 198
    , darkCharcoal = Element.rgb255 0x2E 0x34 0x36
    , lightBlue = Element.rgb255 0xC5 0xE8 0xF7
    , lightGrey = Element.rgb255 0xE0 0xE0 0xE0
    , white = Element.rgb255 0xFF 0xFF 0xFF
    }
