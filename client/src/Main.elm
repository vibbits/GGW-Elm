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
    , currLevel1Overhang : Bsa1Overhang -- Used for filtering the overhangs depending on the application
    , currLevel1App : Application -- Used for filtering the tables on overhang

    -- , level1_construct : Level1
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

    -- Attributes for adding vectors
    , vectorToAdd : Maybe Vector
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
            , currLevel1App = Standard
            , currLevel1Overhang = A__B
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

            -- Attributes for adding vectors
            , vectorToAdd = Nothing
            }
    in
    ( model, router url model )


type Msg
    = GotLoginUrls (Result Http.Error Auth)
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
    | AddBackbone Backbone -- Adds a bacbone to the database
    | UpdateVectorToAdd (Maybe Vector)
      -- | ChangeVectorToAdd ChangeMol --TODO: Delete this
    | RequestGB
    | GBSelected File
    | GBLoaded String
    | AddLevel0 Level0
    | AddLevel1 Level1
    | VectorCreated (Result Http.Error Vector)
      -- Msg for retrieving Vectors
    | VectorsReceived (Result Http.Error (List Vector))
      -- Notifications
    | CloseNotification Int
      -- Constructing Level 1
    | ChangeCurrentLevel1Application Application
    | ChangeCurrentLevel1Bsa1Overhang Bsa1Overhang



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

                        Catalogue ->
                            catalogueView model

                        ConstructLevel1 ->
                            case model.vectorToAdd of
                                Just (LevelNVec vec) ->
                                    constructLevel1View model vec

                                _ ->
                                    constructLevel1View model initLevel1

                        AddLevel0Page ->
                            case model.vectorToAdd of
                                Just (Level0Vec vec) ->
                                    addLevel0View vec

                                _ ->
                                    addLevel0View initLevel0

                        AddBackbonePage ->
                            case model.vectorToAdd of
                                Just (BackboneVec vec) ->
                                    addBackboneView vec

                                _ ->
                                    addBackboneView initBackbone
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
                ]
            )
            model.level1AccordionStatus
        ]


addLevel0View : Level0 -> Element Msg
addLevel0View level0 =
    column [ Element.height Element.fill, padding 25, spacing 25 ]
        [ el [ Element.Region.heading 1, Font.size 50 ] <| Element.text "Add new Level 0 donor vector"
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Name:\t"
            , onChange = \name -> UpdateVectorToAdd <| Just (Level0Vec { level0 | name = name })
            , placeholder = Nothing
            , text = level0.name
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "MP-G0-number:\tMP-G0- "
            , onChange =
                \val ->
                    UpdateVectorToAdd <|
                        Just
                            (Level0Vec
                                { level0
                                    | location =
                                        Maybe.withDefault initLevel0.location <|
                                            String.toInt val
                                }
                            )
            , placeholder = Nothing
            , text = String.fromInt <| level0.location
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Bacterial strain:"
            , onChange = \bacterialStrain -> UpdateVectorToAdd <| Just (Level0Vec { level0 | bacterialStrain = Just bacterialStrain })
            , placeholder = Nothing
            , text = Maybe.withDefault "" level0.bacterialStrain
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Responsible:"
            , onChange = \responsible -> UpdateVectorToAdd <| Just (Level0Vec { level0 | responsible = responsible })
            , placeholder = Nothing
            , text = level0.responsible
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Group:"
            , onChange = \group -> UpdateVectorToAdd <| Just (Level0Vec { level0 | group = group })
            , placeholder = Nothing
            , text = level0.group
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Selection:"
            , onChange = \selection -> UpdateVectorToAdd <| Just (Level0Vec { level0 | selection = Just selection })
            , placeholder = Nothing
            , text = Maybe.withDefault "" level0.selection
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Cloning Technique:"
            , onChange = \cloningtechnique -> UpdateVectorToAdd <| Just (Level0Vec { level0 | cloningTechnique = Just cloningtechnique })
            , placeholder = Nothing
            , text = Maybe.withDefault "" level0.cloningTechnique
            }
        , Input.checkbox []
            { onChange = \isBsmb1Free -> UpdateVectorToAdd <| Just (Level0Vec { level0 | isBsmb1Free = Just isBsmb1Free })
            , icon = Input.defaultCheckbox
            , checked = Maybe.withDefault False level0.isBsmb1Free
            , label = Input.labelLeft [] <| Element.text "Is the construct BsmbI free?"
            }
        , Input.radioRow [ spacing 5, padding 10 ]
            { label = Input.labelAbove [] <| Element.text "BsaI Overhang Type:\t"
            , onChange = \bsa1Overhang -> UpdateVectorToAdd <| Just (Level0Vec { level0 | bsa1Overhang = bsa1Overhang })
            , options =
                makeBsa1OverhangOptions allBsa1Overhangs
            , selected = Just level0.bsa1Overhang
            }
        , Input.multiline [ Element.height <| px 150 ]
            { text = Maybe.withDefault "" level0.notes
            , onChange = \notes -> UpdateVectorToAdd <| Just (Level0Vec { level0 | notes = Just notes })
            , label = Input.labelLeft [] <| Element.text "Notes: "
            , spellcheck = True
            , placeholder = Nothing
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Restriction Site:"
            , onChange = \reaseDigest -> UpdateVectorToAdd <| Just (Level0Vec { level0 | reaseDigest = Just reaseDigest })
            , placeholder = Nothing
            , text = Maybe.withDefault "" level0.reaseDigest
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Date (YYYY-MM-DD): "
            , onChange = \date -> UpdateVectorToAdd <| Just (Level0Vec { level0 | date = Just date })
            , placeholder = Nothing
            , text = Maybe.withDefault "" level0.date
            }
        , Element.html <|
            Html.button
                [ HA.style "margin" "50px"
                , HA.style "font-size" "20px"
                , onClick RequestGB
                ]
                [ Html.text "Load Genbank file"
                ]
        , button_ (Maybe.map AddLevel0 (Just level0)) "Add"
        ]


makeBsa1OverhangOptions : List Bsa1Overhang -> List (Input.Option Bsa1Overhang msg)
makeBsa1OverhangOptions overHangList =
    List.map (\ohang -> Input.option ohang (showBsa1Overhang ohang |> Element.text)) overHangList


makeBsmb1OverhangOptions : List Bsmb1Overhang -> List (Input.Option Bsmb1Overhang msg)
makeBsmb1OverhangOptions overHangList =
    List.map (\ohang -> Input.option ohang (showBsmb1Overhang ohang |> Element.text)) overHangList


addBackboneView : Backbone -> Element Msg
addBackboneView bb =
    column [ Element.height Element.fill, centerX, Element.width Element.fill, spacing 25, padding 25 ]
        [ el [ Element.Region.heading 1, Font.size 50 ] <| Element.text "Add new Backbone"
        , Input.text []
            { onChange =
                \name ->
                    UpdateVectorToAdd <|
                        Just (BackboneVec { bb | name = name })
            , text = bb.name
            , label = Input.labelLeft [] <| Element.text "Name:"
            , placeholder = Nothing
            }
        , Input.text []
            { onChange =
                \val ->
                    UpdateVectorToAdd <|
                        Just (BackboneVec { bb | location = Maybe.withDefault initBackbone.location (String.toInt val) })
            , text = String.fromInt bb.location
            , label = Input.labelLeft [] <| Element.text "MP-GB-number:\tMP-GB-"
            , placeholder = Nothing
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Bacterial strain:"
            , onChange =
                \bacterialStrain ->
                    UpdateVectorToAdd <|
                        Just <|
                            BackboneVec { bb | bacterialStrain = Just bacterialStrain }
            , placeholder = Nothing
            , text = Maybe.withDefault "" bb.bacterialStrain
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Responsible:"
            , onChange =
                \responsible ->
                    UpdateVectorToAdd <|
                        Just <|
                            BackboneVec { bb | responsible = responsible }
            , placeholder = Nothing
            , text = bb.responsible
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Group:"
            , onChange =
                \group ->
                    UpdateVectorToAdd <|
                        Just <|
                            BackboneVec { bb | group = group }
            , placeholder = Nothing
            , text = bb.group
            }
        , Input.radioRow [ spacing 5, padding 10 ]
            { label = Input.labelAbove [] <| Element.text "BsaI Overhang Type:\t"
            , onChange =
                \bsa1Overhang ->
                    UpdateVectorToAdd <|
                        Just <|
                            BackboneVec { bb | bsa1Overhang = Just bsa1Overhang }
            , options =
                makeBsa1OverhangOptions allBsa1Overhangs
            , selected = bb.bsa1Overhang
            }
        , Input.radioRow [ spacing 5, padding 10 ]
            { label = Input.labelAbove [] <| Element.text "BsmBI Overhang Type:\t"
            , onChange =
                \bsmb1Overhang ->
                    UpdateVectorToAdd <|
                        Just <|
                            BackboneVec { bb | bsmb1Overhang = Just bsmb1Overhang }
            , options =
                makeBsmb1OverhangOptions allBsmbs1Overhangs
            , selected = bb.bsmb1Overhang
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Restriction Site:"
            , onChange =
                \reaseDigest ->
                    UpdateVectorToAdd <|
                        Just <|
                            BackboneVec { bb | reaseDigest = Just reaseDigest }
            , placeholder = Nothing
            , text = Maybe.withDefault "" bb.reaseDigest
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Cloning Technique:"
            , onChange =
                \cloningTechnique ->
                    UpdateVectorToAdd <|
                        Just <|
                            BackboneVec { bb | cloningTechnique = Just cloningTechnique }
            , placeholder = Nothing
            , text = Maybe.withDefault "" bb.cloningTechnique
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Selection:"
            , onChange =
                \selection ->
                    UpdateVectorToAdd <|
                        Just <|
                            BackboneVec { bb | selection = Just selection }
            , placeholder = Nothing
            , text = Maybe.withDefault "" bb.selection
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Vector Type:"
            , onChange =
                \vectorType ->
                    UpdateVectorToAdd <|
                        Just <|
                            BackboneVec { bb | vectorType = Just vectorType }
            , placeholder = Nothing
            , text = Maybe.withDefault "" bb.vectorType
            }
        , Input.multiline [ Element.height <| px 150 ]
            { text = Maybe.withDefault "" bb.notes
            , onChange =
                \notes ->
                    UpdateVectorToAdd <|
                        Just <|
                            BackboneVec { bb | notes = Just notes }
            , label = Input.labelLeft [] <| Element.text "Notes: "
            , spellcheck = True
            , placeholder = Nothing
            }
        , Input.text []
            { label = Input.labelLeft [] <| Element.text "Date (YYYY-MM-DD): "
            , onChange =
                \date ->
                    UpdateVectorToAdd <|
                        Just <|
                            BackboneVec { bb | date = Just date }
            , placeholder = Nothing
            , text = Maybe.withDefault "" bb.date
            }
        , Element.html <|
            Html.button
                [ HA.style "margin" "50px"
                , HA.style "font-size" "20px"
                , onClick RequestGB
                ]
                [ Html.text "Load Genbank file" ]
        , button_ (Maybe.map AddBackbone <| Just bb) "Add"
        ]


constructLevel1View : Model -> Level1 -> Element Msg
constructLevel1View model level1 =
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
            { onChange = \name -> UpdateVectorToAdd <| Just <| LevelNVec { level1 | name = name }
            , label = Input.labelLeft [] <| Element.text "Construct name: "
            , text = level1.name
            , placeholder = Nothing
            }
        , Input.text []
            { onChange =
                \location ->
                    UpdateVectorToAdd <|
                        Just <|
                            LevelNVec
                                { level1
                                    | location =
                                        Maybe.withDefault initLevel1.location <|
                                            String.toInt location
                                }
            , label = Input.labelLeft [] <| Element.text "Construct number: "
            , text = String.fromInt level1.location
            , placeholder = Nothing
            }
        , row [ spacing 50 ]
            [ el [] <| Element.text "Length (bp):"
            , el [ padding 10 ] <| Element.text <| String.fromInt <| calculateLevel1Length <| level1
            ]
        , Input.multiline [ Element.height <| px 150 ]
            { text = (.notes >> Maybe.withDefault "") <| level1
            , onChange = \notes -> UpdateVectorToAdd <| Just <| LevelNVec { level1 | notes = Just notes }
            , label = Input.labelLeft [] <| Element.text "Notes: "
            , spellcheck = True
            , placeholder = Nothing
            }
        , Input.text []
            { onChange = \responsible -> UpdateVectorToAdd <| Just <| LevelNVec { level1 | responsible = responsible }
            , label = Input.labelLeft [] <| Element.text "Designer Name: "
            , text = level1.responsible
            , placeholder = Nothing
            }
        , Input.text []
            { onChange = \bacterialStrain -> UpdateVectorToAdd <| Just <| LevelNVec { level1 | bacterialStrain = Just bacterialStrain }
            , label = Input.labelLeft [] <| Element.text "Bacterial strain:"
            , text = Maybe.withDefault "" level1.bacterialStrain
            , placeholder = Nothing
            }
        , Input.text []
            { onChange = \selection -> UpdateVectorToAdd <| Just <| LevelNVec { level1 | selection = Just selection }
            , label = Input.labelLeft [] <| Element.text "Selection:"
            , text = Maybe.withDefault "" level1.selection
            , placeholder = Nothing
            }
        , Input.text []
            { onChange = \date -> UpdateVectorToAdd <| Just <| LevelNVec { level1 | date = Just date }
            , label = Input.labelLeft [] <| Element.text "Choose a date:"
            , text = Maybe.withDefault "" level1.date
            , placeholder = Nothing
            }
        , el
            [ Element.Region.heading 2
            , Font.size 25
            ]
          <|
            Element.text "Destination vector selection"
        , backboneTable model
        , el
            [ Element.Region.heading 2
            , Font.size 25
            ]
          <|
            Element.text "Donor vector selection"
        , applicationRadioButton model
        , overhangRadioRow model
        , level0Table model
        , downloadButtonBar level1
        , el
            [ Element.Region.heading 2
            , Font.size 25
            ]
          <|
            Element.text "Construct visualisation"
        , Element.html <| visualRepresentation level1
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


visualRepresentation : Level1 -> Html Msg
visualRepresentation level1 =
    let
        -- Note: The reversing is for making sure Level0 1 is at position 0. This way the destination vector is appended on the back of the list!
        insertOverhangs =
            getInsertsFromLevel1 level1 |> List.map (.bsa1Overhang >> showBsa1Overhang)

        insertNames =
            getInsertsFromLevel1 level1 |> List.map .name

        insertLengths =
            getInsertsFromLevel1 level1 |> List.map .sequenceLength

        insertTuple =
            List.Extra.zip3 insertNames insertOverhangs insertLengths

        insertRecordList =
            List.map tupleToRecord insertTuple

        sortedInsertRecordList =
            List.sortBy .bsa1_overhang insertRecordList

        chartLabels =
            (Maybe.withDefault "" <| Maybe.map .name level1.backbone) :: List.map .name sortedInsertRecordList

        chartLengths =
            List.reverse (List.map toFloat <| (level1 |> getBackboneFromLevel1 |> .sequenceLength) :: List.reverse (List.map .length sortedInsertRecordList))

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
                [ onClick (UpdateVectorToAdd <| Just <| LevelNVec <| { level1 | inserts = [] })
                , HA.style "margin-right" "75px"
                , HA.style "padding" "10px"
                , HA.style "background-color" "white"
                , HA.style "border-radius" "6px"
                , HA.style "border" "solid 3px rgb(152, 171, 198)"
                ]
                [ Html.text "Reset Level0 List" ]
            , Html.button
                [ onClick
                    (UpdateVectorToAdd <|
                        Just <|
                            LevelNVec <|
                                { level1
                                    | inserts = []
                                    , backbone = Nothing
                                }
                    )
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
                , buttonLink_ (Just (SwitchPage ConstructLevel1)) "New Level1 construct"
                , buttonLink_ Nothing <| Maybe.withDefault "Unknown name" user.name
                , buttonLink_ (Just Logout) "Logout"
                ]

        _ ->
            navBar
                []


downloadButtonBar : Level1 -> Element Msg
downloadButtonBar level1 =
    row
        [ centerX
        , spacing 150
        ]
        [ button_ (Just (AddLevel1 level1)) "Save to database"
        , download_ "./core/Genbank Files/Example_Genbank_format.gb" "Example Genbank File" "Download GenBank"
        ]


overhangRadioRow : Model -> Element Msg
overhangRadioRow model =
    let
        makeButton : Bsa1Overhang -> Input.Option Bsa1Overhang Msg
        makeButton bsa1_overhang =
            showBsa1Overhang bsa1_overhang
                |> option_
                |> Input.optionWith bsa1_overhang

        getOverhangShape : List Bsa1Overhang
        getOverhangShape =
            case model.page of
                ConstructLevel1 ->
                    overhangShape model.currLevel1App

                _ ->
                    allBsa1Overhangs
    in
    Input.radioRow
        []
        { onChange = ChangeCurrentLevel1Bsa1Overhang
        , selected = Just model.currLevel1Overhang
        , label =
            Input.labelAbove
                [ paddingEach { bottom = 20, top = 0, left = 0, right = 0 } ]
            <|
                Element.text "Choose Overhang type"
        , options = List.map makeButton <| getOverhangShape
        }


applicationRadioButton : Model -> Element Msg
applicationRadioButton model =
    Input.radio
        [ padding 10
        , spacing 20
        , Element.width Element.fill
        ]
        { onChange = ChangeCurrentLevel1Application
        , selected = Just model.currLevel1App
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

        viewName : Level0 -> Element Msg
        viewName level0 =
            case model.vectorToAdd of
                Just (LevelNVec level1) ->
                    buttonLink_ (Just (UpdateVectorToAdd <| Just <| LevelNVec <| { level1 | inserts = appendInsertToLevel1 level1.inserts level0 })) level0.name

                _ ->
                    Element.text level0.name
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
                        |> List.filter (filterLevel0OnOverhang model.currLevel1Overhang)
                        |> List.filter (filterMolecule model.level0FilterString)
                , columns =
                    [ { header = none
                      , width = fillPortion 3
                      , view = .location >> String.fromInt >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 5
                      , view = viewName
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

        viewLocation : Backbone -> Element Msg
        viewLocation bb =
            bb.location |> String.fromInt |> Element.text |> el [ centerY ]

        viewName : Backbone -> Element Msg
        viewName backbone =
            case model.vectorToAdd of
                Just (LevelNVec l1) ->
                    buttonLink_ (Just <| UpdateVectorToAdd <| Just <| LevelNVec <| { l1 | backbone = Just backbone }) backbone.name

                _ ->
                    Element.text backbone.name
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
                      , view = viewLocation
                      }
                    , { header = none
                      , width = fillPortion 5
                      , view = viewName
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
        ChangeCurrentLevel1Application newCurrApp ->
            ( { model | currLevel1App = newCurrApp }, Cmd.none )

        ChangeCurrentLevel1Bsa1Overhang newCurrOverhang ->
            ( { model | currLevel1Overhang = newCurrOverhang }, Cmd.none )

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
            ( model, createVector model.auth (BackboneVec newBB) )

        RequestGB ->
            ( model, Select.file [ "text" ] GBSelected )

        GBSelected file ->
            ( model, Task.perform GBLoaded (File.toString file) )

        GBLoaded content ->
            let
                setGBContent : { a | genbankContent : Maybe String } -> { a | genbankContent : Maybe String }
                setGBContent vec =
                    { vec | genbankContent = Just content }
            in
            case model.vectorToAdd of
                Just (BackboneVec backbone) ->
                    ( { model | vectorToAdd = Just (BackboneVec <| setGBContent backbone) }, Cmd.none )

                Just (Level0Vec l) ->
                    ( { model | vectorToAdd = Just (Level0Vec <| setGBContent l) }, Cmd.none )

                Just (LevelNVec l) ->
                    ( { model | vectorToAdd = Just (LevelNVec <| setGBContent l) }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        UpdateVectorToAdd vector ->
            ( { model | vectorToAdd = vector }, Cmd.none )

        AddLevel0 newIns ->
            ( model, createVector model.auth (Level0Vec newIns) )

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

        AddLevel1 level1 ->
            ( model, createVector model.auth (LevelNVec level1) )



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



-- Helper functions


calculateLevel1Length : Level1 -> Int
calculateLevel1Length l1 =
    List.sum
        ((Maybe.withDefault 0 <| Maybe.map .sequenceLength l1.backbone)
            :: List.map .sequenceLength l1.inserts
        )


getInsertsFromLevel1 : Level1 -> List Level0
getInsertsFromLevel1 level1 =
    level1.inserts


getBackboneFromLevel1 : Level1 -> Backbone
getBackboneFromLevel1 level1 =
    Maybe.withDefault initBackbone level1.backbone


appendInsertToLevel1 : List Level0 -> Level0 -> List Level0
appendInsertToLevel1 l0List newL0 =
    if not (List.member newL0.bsa1Overhang (List.map .bsa1Overhang <| l0List)) then
        List.append l0List [ newL0 ]

    else
        newL0
            :: List.filter
                (\l0 ->
                    l0.bsa1Overhang /= newL0.bsa1Overhang
                )
                l0List



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
                        "http://localhost:8000/vectors/leveln/"
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
