module Main exposing (..)

import Accordion
import Array exposing (Array)
import Auth
    exposing
        ( Auth(..)
        , AuthCode
        , Login
        , authCode
        , authDecoder
        )
import Browser exposing (Document)
import Browser.Dom exposing (Error(..))
import Browser.Navigation as Nav
import Color
import Dict
import Element exposing (..)
import Element.Border as Border
import Element.Events as EE
import Element.Font as Font
import Element.Input as Input
import Element.Region
import File exposing (File)
import File.Select as Select
import Html exposing (Html)
import Html.Attributes as HA
import Html.Events exposing (onClick)
import Http exposing (Error(..), expectJson, jsonBody)
import Interface
    exposing
        ( addButton
        , buttonLink_
        , button_
        , download_
        , linkButton_
        , navBar
        , option_
        , title
        , viewMaybe
        )
import Json.Decode as Decode
import Json.Encode as Encode
import List
import List.Extra
import Molecules exposing (..)
import Path
import Shape exposing (defaultPieConfig)
import Storage
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
    , level1ToAdd : Maybe Level1
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
    , vectors : List Vector

    -- Attributes for adding backbones
    , backboneToAdd : Maybe Backbone

    -- Attributes for adding Level0
    , level0ToAdd : Maybe Level0
    }


init : Decode.Value -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        auth : Auth
        auth =
            Storage.fromJson flags

        page : DisplayPage
        page =
            case auth of
                Authenticated _ ->
                    Catalogue

                _ ->
                    LoginPage

        model : Model
        model =
            { page = page
            , currApp = Standard
            , currOverhang = A__B
            , level1ToAdd = Nothing

            -- |
            , auth = Storage.fromJson flags
            , notifications = Notify.init
            , key = key
            , backboneFilterString = Nothing
            , level0FilterString = Nothing
            , level1FilterString = Nothing
            , backboneAccordionStatus = False
            , level0AccordionStatus = False
            , level1AccordionStatus = False
            , vectors = []

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
    | FiveAC
    | Four
    | FourAC
    | Three
    | ThreeAC


type Msg
    = -- Level 1 construction Msg
      ChooseApplication Application
    | ChangeOverhang Bsa1Overhang
      -- Login Msg
    | GotLoginUrls (Result Http.Error Auth)
    | GotAuthentication (Result Http.Error Auth)
    | Logout
    | UrlChanged Url
    | LinkClicked Browser.UrlRequest
      -- Msg Switching pages
    | SwitchPage DisplayPage
      -- Vector catalogue Msg
    | BackboneAccordionToggled -- TODO: Unify these 3
    | Level0AccordionToggled
    | Level1AccordionToggled
    | ToggleAll
    | FilterBackboneTable String -- TODO: Unify
    | FilterLevel0Table String
    | FilterLevel1Table String
    | AddBackbone Backbone
    | ChangeBackboneToAdd ChangeMol
    | RequestGBBackbone
    | GBSelectedBackbone File
    | AddLevel0 Level0
    | ChangeLevel0ToAdd ChangeMol
    | RequestGBLevel0
    | GBSelectedLevel0 File
    | ChangeLevel1ToAdd ChangeMol
    | AddLevel1
      -- Msg for Adding vectors to the DB
    | VectorCreated (Result Http.Error Vector)
      -- Msg for retrieving Vectors
    | VectorsReceived (Result Http.Error (List Vector))
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
            ]
            (row
                [ Element.width Element.fill
                , Element.height Element.fill
                ]
                [ navLinks model.auth
                , el
                    [ Element.width Element.fill
                    , Element.height Element.fill
                    , Element.scrollbarY
                    ]
                    (case model.page of
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
                    )
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
            [ button_ (Just ToggleAll) "Toggle all"
            ]
        , Accordion.accordion
            (Accordion.head
                [ EE.onClick BackboneAccordionToggled
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
                    [ addButton (SwitchPage AddBackbonePage) ]
                ]
            )
            model.backboneAccordionStatus
        , Accordion.accordion
            (Accordion.head
                [ EE.onClick Level0AccordionToggled
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
                , level0Table model
                , Element.row [ centerX, spacing 50 ] [ addButton (SwitchPage AddLevel0Page) ]
                ]
            )
            model.level0AccordionStatus
        , Accordion.accordion
            (Accordion.head
                [ EE.onClick Level1AccordionToggled
                , padding 25
                , Border.solid
                , Border.rounded 6
                ]
                [ Element.text "Level 1"
                ]
            )
            (Accordion.body [ padding 25 ]
                [ Input.text []
                    { onChange = FilterLevel1Table
                    , text = Maybe.withDefault "" model.level1FilterString
                    , label = Input.labelLeft [] <| Element.text "Filter:"
                    , placeholder = Nothing
                    }
                , level1Table model
                , Element.row
                    [ centerX
                    , spacing 50
                    ]
                    [ addButton (SwitchPage ConstructLevel1) ]
                ]
            )
            model.level1AccordionStatus
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
            , onChange =
                \val ->
                    String.toInt val
                        |> Maybe.map (ChangeMPG >> ChangeLevel0ToAdd)
                        |> Maybe.withDefault (ChangeLevel0ToAdd (ChangeMPG 0))
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map (.location >> String.fromInt) model.level0ToAdd
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Bacterial strain:"
            , onChange = ChangeBacterialStrain >> ChangeLevel0ToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map (.bacterialStrain >> Maybe.withDefault "") model.level0ToAdd
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Responsible:"
            , onChange = ChangeResponsible >> ChangeLevel0ToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map .responsible model.level0ToAdd
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Group:"
            , onChange = ChangeGroup >> ChangeLevel0ToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map .group model.level0ToAdd
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Selection:"
            , onChange = ChangeSelection >> ChangeLevel0ToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map (.selection >> Maybe.withDefault "") model.level0ToAdd
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Cloning Technique:"
            , onChange = ChangeCloningTechnique >> ChangeLevel0ToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map (.cloningTechnique >> Maybe.withDefault "") model.level0ToAdd
            }
        , Input.checkbox []
            { onChange = ChangeIsBsmB1Free >> ChangeLevel0ToAdd
            , icon = Input.defaultCheckbox
            , checked = Maybe.withDefault False <| Maybe.map (.isBsmb1Free >> Maybe.withDefault False) model.level0ToAdd
            , label = Input.labelLeft [] <| Element.text "Is the construct BsmbI free?"
            }
        , Input.radioRow [ spacing 5, padding 10 ]
            { label = Input.labelAbove [] <| Element.text "BsaI Overhang Type:\t"
            , onChange = ChangeBsa1 >> ChangeLevel0ToAdd
            , options =
                makeBsa1OverhangOptions allBsa1Overhangs
            , selected = Maybe.map .bsa1Overhang model.level0ToAdd
            }
        , Input.multiline [ Element.height <| px 150 ]
            { text = Maybe.withDefault "" <| Maybe.map (.notes >> Maybe.withDefault "") model.level0ToAdd
            , onChange = ChangeNotes >> ChangeLevel0ToAdd
            , label = Input.labelLeft [] <| Element.text "Notes: "
            , spellcheck = True
            , placeholder = Nothing
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Restriction Site:"
            , onChange = ChangeReaseDigest >> ChangeLevel0ToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map (.reaseDigest >> Maybe.withDefault "") model.level0ToAdd
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Date (YYYY-MM-DD): "
            , onChange = ChangeDate >> ChangeLevel0ToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map (.date >> Maybe.withDefault "") model.level0ToAdd
            }
        , Element.html <|
            Html.button
                [ HA.style "margin" "50px"
                , HA.style "font-size" "20px"
                , onClick RequestGBLevel0
                ]
                [ Html.text "Load Genbank file"
                ]
        , button_ (Maybe.map AddLevel0 model.level0ToAdd) "Add"
        ]


makeBsa1OverhangOptions : List Bsa1Overhang -> List (Input.Option Bsa1Overhang msg)
makeBsa1OverhangOptions overHangList =
    List.map (\ohang -> Input.option ohang (showBsa1Overhang ohang |> Element.text)) overHangList


makeBsmb1OverhangOptions : List Bsmb1Overhang -> List (Input.Option Bsmb1Overhang msg)
makeBsmb1OverhangOptions overHangList =
    List.map (\ohang -> Input.option ohang (showBsmb1Overhang ohang |> Element.text)) overHangList


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
            { onChange =
                \val ->
                    String.toInt val
                        |> Maybe.map (ChangeMPG >> ChangeBackboneToAdd)
                        |> Maybe.withDefault (ChangeBackboneToAdd (ChangeMPG 0))
            , text = Maybe.withDefault "" <| Maybe.map (.location >> String.fromInt) model.backboneToAdd
            , label = Input.labelLeft [] <| Element.text "MP-GB-number:\tMP-GB-"
            , placeholder = Nothing
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Bacterial strain:"
            , onChange = ChangeBacterialStrain >> ChangeBackboneToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map (.bacterialStrain >> Maybe.withDefault "") model.backboneToAdd
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Responsible:"
            , onChange = ChangeResponsible >> ChangeBackboneToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map .responsible model.backboneToAdd
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Group:"
            , onChange = ChangeGroup >> ChangeBackboneToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map .group model.backboneToAdd
            }
        , Input.radioRow [ spacing 5, padding 10 ]
            { label = Input.labelAbove [] <| Element.text "BsaI Overhang Type:\t"
            , onChange = ChangeBsa1 >> ChangeBackboneToAdd
            , options =
                makeBsa1OverhangOptions allBsa1Overhangs
            , selected = Maybe.andThen .bsa1Overhang model.backboneToAdd
            }
        , Input.radioRow [ spacing 5, padding 10 ]
            { label = Input.labelAbove [] <| Element.text "BsmBI Overhang Type:\t"
            , onChange = ChangeBsmb1 >> ChangeBackboneToAdd
            , options =
                makeBsmb1OverhangOptions allBsmbs1Overhangs
            , selected = Maybe.andThen .bsmb1Overhang model.backboneToAdd
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Restriction Site:"
            , onChange = ChangeReaseDigest >> ChangeBackboneToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map (.reaseDigest >> Maybe.withDefault "") model.backboneToAdd
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Cloning Technique:"
            , onChange = ChangeCloningTechnique >> ChangeBackboneToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map (.cloningTechnique >> Maybe.withDefault "") model.backboneToAdd
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Selection:"
            , onChange = ChangeSelection >> ChangeBackboneToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map (.selection >> Maybe.withDefault "") model.backboneToAdd
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Vector Type:"
            , onChange = ChangeVectorType >> ChangeBackboneToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map (.vectorType >> Maybe.withDefault "") model.backboneToAdd
            }
        , Input.multiline [ Element.height <| px 150 ]
            { text = Maybe.withDefault "" <| Maybe.map (.notes >> Maybe.withDefault "") model.backboneToAdd
            , onChange = ChangeNotes >> ChangeBackboneToAdd
            , label = Input.labelLeft [] <| Element.text "Notes: "
            , spellcheck = True
            , placeholder = Nothing
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Date (YYYY-MM-DD): "
            , onChange = ChangeDate >> ChangeBackboneToAdd
            , placeholder = Nothing
            , text = Maybe.withDefault "" <| Maybe.map (.date >> Maybe.withDefault "") model.backboneToAdd
            }
        , Element.html <|
            Html.button
                [ HA.style "margin" "50px"
                , HA.style "font-size" "20px"
                , onClick RequestGBBackbone
                ]
                [ Html.text "Load Genbank file" ]
        , button_ (Maybe.map AddBackbone model.backboneToAdd) "Add"
        ]


constructLevel1View : Model -> Element Msg
constructLevel1View model =
    column [ Element.height Element.fill, spacing 25, Element.width Element.fill, centerX, padding 50 ]
        [ el
            [ Element.Region.heading 1
            , Font.size 50
            ]
          <|
            Element.text "Level 1 construct design"
        , el
            [ Element.Region.heading 2
            , Font.size 25
            ]
          <|
            Element.text "Construct information"
        , Input.text []
            { onChange = ChangeLevel1ToAdd << ChangeName
            , label = Input.labelLeft [] <| Element.text "Construct name: "
            , text = .name (Maybe.withDefault initLevel1 model.level1ToAdd)
            , placeholder = Nothing
            }
        , Input.text []
            { onChange =
                \val ->
                    String.toInt val
                        |> Maybe.map (ChangeMPG >> ChangeLevel1ToAdd)
                        |> Maybe.withDefault (ChangeLevel1ToAdd (ChangeMPG 0))
            , label = Input.labelLeft [] <| Element.text "Construct number: "
            , text = String.fromInt <| .location <| Maybe.withDefault initLevel1 model.level1ToAdd
            , placeholder = Nothing
            }
        , row [ spacing 50 ]
            [ el [] <| Element.text "Length (bp):"
            , el [ padding 10 ] <|
                Element.text <|
                    String.fromInt <|
                        calculateLevel1Length <|
                            model.level1ToAdd
            ]
        , Input.multiline [ Element.height <| px 150 ]
            { text = Maybe.withDefault "" <| Maybe.andThen .notes model.level1ToAdd
            , onChange = ChangeLevel1ToAdd << ChangeNotes
            , label = Input.labelLeft [] <| Element.text "Notes: "
            , spellcheck = True
            , placeholder = Nothing
            }
        , Input.text []
            { onChange = ChangeLevel1ToAdd << ChangeResponsible
            , label = Input.labelLeft [] <| Element.text "Designer Name: "
            , text = .responsible <| Maybe.withDefault initLevel1 model.level1ToAdd
            , placeholder = Nothing
            }
        , Input.text []
            { onChange = ChangeLevel1ToAdd << ChangeBacterialStrain
            , label = Input.labelLeft [] <| Element.text "Bacterial strain:"
            , text = Maybe.withDefault "" <| Maybe.andThen .bacterialStrain model.level1ToAdd
            , placeholder = Nothing
            }
        , Input.text []
            { onChange = ChangeLevel1ToAdd << ChangeSelection
            , label = Input.labelLeft [] <| Element.text "Selection:"
            , text = Maybe.withDefault "" <| Maybe.andThen .selection model.level1ToAdd
            , placeholder = Nothing
            }
        , Input.text []
            { onChange = ChangeLevel1ToAdd << ChangeDate
            , label = Input.labelLeft [] <| Element.text "Choose a date:"
            , text = Maybe.withDefault "" <| Maybe.andThen .date model.level1ToAdd
            , placeholder = Nothing
            }
        , el
            [ Element.Region.heading 2
            , Font.size 25
            ]
          <|
            Element.text "Destination vector selection"
        , Input.text []
            { onChange = FilterBackboneTable
            , text = Maybe.withDefault "" model.backboneFilterString
            , label = Input.labelLeft [] <| Element.text "Filter:"
            , placeholder = Nothing
            }
        , backboneTable model
        , el
            [ Element.Region.heading 2
            , Font.size 25
            ]
          <|
            Element.text "Donor vector selection"
        , applicationRadioButton model
        , overhangRadioRow model
        , Input.text []
            { onChange = FilterLevel0Table
            , text = Maybe.withDefault "" model.level0FilterString
            , label = Input.labelLeft [] <| Element.text "Filter:"
            , placeholder = Nothing
            }
        , level0Table model
        , downloadButtonBar
        , el
            [ Element.Region.heading 2
            , Font.size 25
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
                    :: List.map (\lgn -> linkButton_ lgn.url lgn.name) loginUrls
            ]



-- Visual Representation
-- TODO: This should go in a seperate module


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


getInsertsFromLevel1 : Maybe Level1 -> List Level0
getInsertsFromLevel1 level1 =
    case level1 of
        Just l1 ->
            l1.inserts

        Nothing ->
            []


getBackboneFromLevel1 : Maybe Level1 -> Backbone
getBackboneFromLevel1 level1 =
    case level1 of
        Just l1 ->
            Maybe.withDefault initBackbone l1.backbone

        Nothing ->
            initBackbone


visualRepresentation : Model -> Html Msg
visualRepresentation model =
    let
        -- Note: The reversing is for making sure Level0 1 is at position 0. This way the destination vector is appended on the back of the list!
        insertOverhangs =
            getInsertsFromLevel1 model.level1ToAdd |> List.map (.bsa1Overhang >> showBsa1Overhang)

        insertNames =
            getInsertsFromLevel1 model.level1ToAdd |> List.map .name

        insertLengths =
            getInsertsFromLevel1 model.level1ToAdd |> List.map .sequenceLength

        insertTuple =
            List.Extra.zip3 insertNames insertOverhangs insertLengths

        insertRecordList =
            List.map tupleToRecord insertTuple

        sortedInsertRecordList =
            List.sortBy .bsa1_overhang insertRecordList

        chartLabels =
            .name (getBackboneFromLevel1 model.level1ToAdd) :: List.map .name sortedInsertRecordList

        chartLengths =
            List.reverse (List.map toFloat <| (model.level1ToAdd |> getBackboneFromLevel1 |> .sequenceLength) :: List.reverse (List.map .length sortedInsertRecordList))

        data =
            List.map2 Tuple.pair chartLabels chartLengths

        pieData =
            data |> List.map Tuple.second |> Shape.pie { defaultPieConfig | outerRadius = radius, innerRadius = 0.9 * radius, sortingFn = \_ _ -> EQ }
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
                [ onClick (ChangeLevel1ToAdd ResetInsertList)
                , HA.style "margin-right" "75px"
                , HA.style "padding" "10px"
                , HA.style "background-color" "white"
                , HA.style "border-radius" "6px"
                , HA.style "border" "solid 3px rgb(152, 171, 198)"
                ]
                [ Html.text "Reset Level0 List" ]
            , Html.button
                [ onClick (ChangeLevel1ToAdd ResetAll)
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


navLinks : Auth -> Element Msg
navLinks auth =
    case auth of
        Authenticated user ->
            navBar
                [ buttonLink_ (Just (SwitchPage Catalogue)) "Home"
                , buttonLink_ (Just (SwitchPage Catalogue)) "Vector Catalogue"
                , buttonLink_ Nothing <| Maybe.withDefault "Unknown name" user.name
                , buttonLink_ (Just Logout) "Logout"
                ]

        _ ->
            navBar
                []


downloadButtonBar : Element Msg
downloadButtonBar =
    row
        [ centerX
        , spacing 150
        ]
        [ button_ (Just AddLevel1) "Save to database"
        , download_ "./Example_Data/Example_Genbank_format.gb" "" "Download GenBank"
        ]


overhangRadioRow : Model -> Element Msg
overhangRadioRow model =
    let
        makeButton : Bsa1Overhang -> Input.Option Bsa1Overhang Msg
        makeButton bsa1_overhang =
            showBsa1Overhang bsa1_overhang
                |> option_
                |> Input.optionWith bsa1_overhang

        getOverhangs : Model -> List Bsa1Overhang
        getOverhangs mdl =
            case mdl.page of
                ConstructLevel1 ->
                    overhangShape mdl.currApp

                _ ->
                    allBsa1Overhangs
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
        , options = List.map makeButton <| getOverhangs model
        }


applicationRadioButton : Model -> Element Msg
applicationRadioButton model =
    Input.radio
        [ padding 10
        , spacing 20
        , Element.width Element.fill
        ]
        { onChange = ChooseApplication
        , selected = Just model.currApp
        , label = Input.labelAbove [] <| Element.text "Choose a type of application:"
        , options =
            [ Input.option Standard <| Element.text "Standard application with 6 inserts"
            , Input.option Five <| Element.text "Custom - 5 inserts"
            , Input.option FiveAC <| Element.text "Custom - 5 inserts with A__C"
            , Input.option Four <| Element.text "Custom - 4 inserts"
            , Input.option FourAC <| Element.text "Custom - 4 inserts with A__C"
            , Input.option Three <| Element.text "Custom - 3 inserts"
            , Input.option ThreeAC <| Element.text "Custom - 3 inserts with A__C"
            ]
        }


level0Table : Model -> Element Msg
level0Table model =
    let
        headerAttrs =
            [ Font.bold ]

        insertList : List Level0
        insertList =
            List.filterMap onlyLevel0 model.vectors

        onlyLevel0 : Vector -> Maybe Level0
        onlyLevel0 vec =
            case vec of
                Level0Vec level0 ->
                    Just level0

                _ ->
                    Nothing
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
                    insertList
                        |> List.filter (filterLevel0OnOverhang model.currOverhang)
                        |> List.filter (filterMolecule model.level0FilterString)
                , columns =
                    [ { header = none
                      , width = fillPortion 3
                      , view = .location >> String.fromInt >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 5
                      , view =
                            \level0 -> buttonLink_ (Just ((ChangeLevel1ToAdd << AppendInsert) level0)) level0.name
                      }
                    , { header = none
                      , width = fillPortion 1
                      , view = .sequenceLength >> String.fromInt >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 1
                      , view = .bsa1Overhang >> showBsa1Overhang >> Element.text
                      }
                    ]
                }
        ]


level1Table : Model -> Element Msg
level1Table model =
    let
        headerAttrs =
            [ Font.bold
            , Border.widthEach { bottom = 2, top = 0, left = 0, right = 0 }
            ]

        level1List : List Level1
        level1List =
            List.filterMap onlyLevel1 model.vectors

        onlyLevel1 : Vector -> Maybe Level1
        onlyLevel1 vec =
            case vec of
                LevelNVec level1 ->
                    Just level1

                _ ->
                    Nothing
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
            [ el ((Element.width <| fillPortion 3) :: headerAttrs) <| Element.text "MP-G1-Number"
            , el ((Element.width <| fillPortion 5) :: headerAttrs) <| Element.text "Level1 Name"
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
                , spacing 20
                , padding 25
                ]
                { data = List.filter (filterMolecule model.level1FilterString) level1List
                , columns =
                    [ { header = none
                      , width = fillPortion 3
                      , view = .location >> String.fromInt >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 5
                      , view = .name >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 1
                      , view = .sequenceLength >> String.fromInt >> Element.text >> el [ centerY ]
                      }
                    ]
                }
        ]


backboneTable : Model -> Element Msg
backboneTable model =
    let
        headerAttrs =
            [ Font.bold ]

        backboneList : List Backbone
        backboneList =
            List.filterMap onlyBackbone model.vectors

        onlyBackbone : Vector -> Maybe Backbone
        onlyBackbone vec =
            case vec of
                BackboneVec backbone ->
                    Just backbone

                _ ->
                    Nothing
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
                { data = List.filter (filterMolecule model.backboneFilterString) backboneList
                , columns =
                    [ { header = none
                      , width = fillPortion 3
                      , view = .location >> String.fromInt >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 5
                      , view =
                            \backbone -> buttonLink_ (Just ((ChangeLevel1ToAdd << AppendBackbone) backbone)) backbone.name
                      }
                    , { header = none
                      , width = fillPortion 1
                      , view = .sequenceLength >> String.fromInt >> Element.text >> el [ centerY ]
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
            Dict.get "6" overhangs

        Five ->
            Dict.get "5" overhangs

        FiveAC ->
            Dict.get "5AC" overhangs

        Four ->
            Dict.get "4" overhangs

        FourAC ->
            Dict.get "4AC" overhangs

        Three ->
            Dict.get "3" overhangs

        ThreeAC ->
            Dict.get "3AC" overhangs
    )
        |> Maybe.withDefault default


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ChangeOverhang newOverhang ->
            ( { model | currOverhang = newOverhang }, Cmd.none )

        ChooseApplication newApp ->
            ( { model | currApp = newApp }, Cmd.none )

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
                    ( { model | auth = auth, page = Catalogue }
                    , Cmd.batch [ navToRoot, getVectors auth, Storage.toJson auth |> Storage.save ]
                    )

                Err err ->
                    ( { model
                        | notifications = Notify.makeError "Logging in" (showHttpError err) model.notifications
                      }
                    , navToRoot
                    )

        Logout ->
            ( { model | auth = Auth.init, page = LoginPage }
            , Cmd.batch [ Nav.pushUrl model.key "/login", Storage.toJson Auth.init |> Storage.save ]
            )

        SwitchPage page ->
            ( { model
                | page = page
                , backboneFilterString = Nothing
                , level0FilterString = Nothing
                , level1FilterString = Nothing
              }
            , Cmd.none
            )

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
            ( model, createVector model.auth (BackboneVec newBB) )

        RequestGBBackbone ->
            ( model, Select.file [ "text" ] GBSelectedBackbone )

        GBSelectedBackbone file ->
            ( model, Task.perform (ChangeBackboneToAdd << ChangeGB) (File.toString file) )

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
            ( model, createVector model.auth (Level0Vec newIns) )

        RequestGBLevel0 ->
            ( model, Select.file [ "text" ] GBSelectedLevel0 )

        GBSelectedLevel0 file ->
            ( model, Task.perform (ChangeLevel0ToAdd << ChangeGB) (File.toString file) )

        ChangeLevel0ToAdd change ->
            ( { model
                | level0ToAdd =
                    Maybe.withDefault initLevel0 model.level0ToAdd
                        |> interpretLevel0Change change
                        |> Just
              }
            , Cmd.none
            )

        AddLevel1 ->
            ( model, createVector model.auth (LevelNVec <| Maybe.withDefault initLevel1 model.level1ToAdd) )

        ChangeLevel1ToAdd change ->
            ( { model
                | level1ToAdd =
                    Maybe.withDefault initLevel1 model.level1ToAdd
                        |> interpretLevel1Change change
                        |> Just
              }
            , Cmd.none
            )

        CloseNotification which ->
            ( { model | notifications = Notify.close which model.notifications }
            , Cmd.none
            )

        VectorsReceived (Ok vectors) ->
            ( { model | vectors = vectors }, Cmd.none )

        VectorsReceived (Err err) ->
            ( { model | notifications = Notify.makeError "Fetching vectors" (showHttpError err) model.notifications }
            , Cmd.none
            )

        VectorCreated (Err err) ->
            ( { model | notifications = Notify.makeError "Creating new vector failed" (showHttpError err) model.notifications }
            , Cmd.none
            )

        VectorCreated (Ok vec) ->
            ( { model
                | vectors = vec :: model.vectors
                , page = Catalogue
              }
            , Cmd.none
            )



-- Filter functions


filterMolecule : Maybe String -> { a | name : String, location : Int } -> Bool
filterMolecule needle val =
    case needle of
        Nothing ->
            True

        Just ndle ->
            String.contains (String.toLower ndle) (String.toLower val.name)
                || String.contains ndle (String.fromInt val.location)


filterLevel0OnOverhang : Bsa1Overhang -> Level0 -> Bool
filterLevel0OnOverhang needle val =
    needle == val.bsa1Overhang


calculateLevel1Length : Maybe Level1 -> Int
calculateLevel1Length level1 =
    case level1 of
        Just l1 ->
            List.sum
                ((Maybe.withDefault 0 <| Maybe.map .sequenceLength l1.backbone)
                    :: List.map .sequenceLength l1.inserts
                )

        Nothing ->
            0



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


authenticatedPost : String -> String -> (Result Http.Error a -> Msg) -> Encode.Value -> Decode.Decoder a -> Cmd Msg
authenticatedPost token url msg payload decoder =
    Http.request
        { method = "POST"
        , headers = [ Http.header "Authorization" ("Bearer " ++ token) ]
        , url = url
        , body = Http.jsonBody payload
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


getVectors : Auth -> Cmd Msg
getVectors auth =
    case auth of
        Authenticated usr ->
            authenticatedGet usr.token
                "http://localhost:8000/vectors/"
                VectorsReceived
                vectorDecoder

        _ ->
            Cmd.none


createVector : Auth -> Vector -> Cmd Msg
createVector auth vector =
    case auth of
        Authenticated usr ->
            case vector of
                LevelNVec _ ->
                    authenticatedPost usr.token
                        "http://localhost:8000/leveln/"
                        VectorCreated
                        (vectorEncoder vector)
                        vectorDecoder_

                _ ->
                    authenticatedPost usr.token
                        "http://localhost:8000/vectors/"
                        VectorCreated
                        (vectorEncoder vector)
                        vectorDecoder_

        _ ->
            Cmd.none



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


main : Program Decode.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }
