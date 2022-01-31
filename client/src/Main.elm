module Main exposing (..)

import Accordion
import Array exposing (Array)
import Browser exposing (Document)
import Browser.Dom exposing (Error(..))
import Browser.Navigation as Nav
import Color
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border exposing (rounded)
import Element.Events as EE
import Element.Font as Font
import Element.Input as Input
import Element.Region
import File exposing (File)
import File.Select as Select
import Html exposing (Html, a)
import Html.Attributes as HA
import Html.Events exposing (onClick)
import Http exposing (Error(..), expectJson, jsonBody)
import Json.Decode as Decode
import Json.Decode.Pipeline as JDP
import Json.Encode as Encode
import List
import List.Extra
import Path
import Shape exposing (defaultPieConfig)
import String
import Task
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
    , selectedInserts : List Level0
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
    , insertList : List Level0

    -- Attributes for adding backbones
    , nameBackboneToAdd : String
    , mpgbNumberBackboneToAdd : String
    , levelBackboneToAdd : Int
    , lengthBackboneToAdd : Int
    , backboneGenbankContent : Maybe String

    -- Attributes for adding Level0
    , nameLevel0ToAdd : String
    , mpg0NumberLevel0ToAdd : String
    , bsa1OverhangLevel0ToAdd : Maybe Overhang
    , lengthLevel0ToAdd : Int
    , bacterialStrainLevel0ToAdd : String
    , responsibleLevel0ToAdd : String
    , groupLevel0ToAdd : String
    , selectionLevel0ToAdd : String
    , cloningTechniqueLevel0ToAdd : String
    , isBsmB1FreeLevel0ToAdd : IsPresent
    , notesLevel0ToAdd : Maybe String
    , reAseDigestLevel0ToAdd : String
    , sequenceLevel0ToAdd : String
    , annotationsLevel0ToAdd : List Annotation
    , featuresLevel0ToAdd : List Feature
    , referencesLevel0ToAdd : List Reference
    , level0GenbankContent : Maybe String
    }


type alias Annotation =
    { key : String
    , value : String
    }


type alias Qualifier =
    { key : String
    , value : String
    }


type alias Feature =
    { feature_type : String
    , qualifiers : List Qualifier
    , start_pos : Int
    , end_pos : Int
    , strand : Int
    }


type alias Reference =
    { authors : String
    , title : String
    }


type alias Level0 =
    { name : String
    , mPG0Number : String
    , bsa1_overhang : Overhang
    , bacterial_strain : String
    , responsible : String
    , group : String
    , selection : String
    , cloning_technique : String
    , is_BsmB1_free : IsPresent
    , notes : Maybe String
    , re_ase_digest : String
    , sequence : String
    , annotations : List Annotation
    , features : List Feature
    , references : List Reference
    }


emptyInsertList : List Level0
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
      , backboneList = []
      , insertList = []

      -- Backbone To Add attributes
      , nameBackboneToAdd = ""
      , mpgbNumberBackboneToAdd = ""
      , levelBackboneToAdd = 0
      , lengthBackboneToAdd = 0
      , backboneGenbankContent = Nothing

      -- Level0 To Add Attributes
      , nameLevel0ToAdd = ""
      , mpg0NumberLevel0ToAdd = ""
      , bsa1OverhangLevel0ToAdd = Nothing
      , lengthLevel0ToAdd = 0
      , bacterialStrainLevel0ToAdd = ""
      , responsibleLevel0ToAdd = ""
      , groupLevel0ToAdd = ""
      , selectionLevel0ToAdd = ""
      , cloningTechniqueLevel0ToAdd = ""
      , isBsmB1FreeLevel0ToAdd = Unknown
      , notesLevel0ToAdd = Nothing
      , reAseDigestLevel0ToAdd = ""
      , sequenceLevel0ToAdd = ""
      , annotationsLevel0ToAdd = []
      , featuresLevel0ToAdd = []
      , referencesLevel0ToAdd = []
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


type ButtonPosition
    = First
    | Mid
    | Last


type Msg
    = -- Level 1 construction Msg
      ChooseApplication Application
    | ChangeOverhang Overhang
    | ChangeConstructName String
    | ChangeConstructNumber String
    | ChangeApplicationNote String
    | ChangeConstructDesignerName String
    | ChangeDescription String
    | AppendInsert Level0
    | ChangeBackbone Backbone
    | ResetInsertList
    | ResetBackbone
      -- Login Msg
    | GotLoginUrls (Result Http.Error (List Login))
    | UrlChanged
    | LinkClicked Browser.UrlRequest
    | GotAuthentication (Result Http.Error AuthenticationResponse)
      -- Msg Switching pages
    | SwitchPage DisplayPage
      -- Vector catalogue Msg
    | BackboneAccordionToggled
    | Level0AccordionToggled
    | ToggleAll
    | FilterBackboneTable String
    | FilterLevel0Table String
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
    | AddLevel0 Level0
    | ChangeLevel0NameToAdd String
    | ChangeLevel0MpgNumberToAdd String
    | ChangeLevel0OverhangToAdd Overhang
    | GBNewLevel0Requested
    | GBNewLevel0Selected File
    | GbNewLevel0Loaded String
      -- Msg for retrieving Vectors
    | RequestAllLevel0
    | Level0Received (Result Http.Error (List Level0))



-- view


view : Model -> Document Msg
view model =
    case model.page of
        ConstructLevel1 ->
            constructLevel1View model

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
            row
                [ Element.width Element.fill
                , spacing 25
                , padding 10
                ]
                [ navLinks
                , column [ spacing 25, Element.width Element.fill, centerX, padding 50 ]
                    [ el
                        [ Element.Region.heading 1
                        , Font.size 50
                        , Font.color color.darkCharcoal
                        ]
                      <|
                        Element.text "Vector Catalog"
                    , row [ spacing 20 ]
                        [ Input.button
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
                            { onPress = Just RequestAllLevel0
                            , label = Element.text "Populate table from DB"
                            }
                        ]
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
                            ]
                            [ Element.text "Level 0\t▼"
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
                    , Input.radioRow [ spacing 5, padding 10 ]
                        { label = Input.labelAbove [] <| Element.text "Overhang Type:\t"
                        , onChange = ChangeLevel0OverhangToAdd
                        , options =
                            makeOverhangOptions completeOverhangList
                        , selected = model.bsa1OverhangLevel0ToAdd
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
                        , onPress = Maybe.map (makeLevel0 model) model.bsa1OverhangLevel0ToAdd
                        }
                    ]
                ]
        ]
    }


makeLevel0 : Model -> Overhang -> Msg
makeLevel0 model bsa1_overhang =
    AddLevel0
        { name = model.nameLevel0ToAdd
        , mPG0Number = "MP-G0-" ++ model.mpg0NumberLevel0ToAdd
        , bsa1_overhang = bsa1_overhang
        , bacterial_strain = model.bacterialStrainLevel0ToAdd
        , responsible = model.responsibleLevel0ToAdd
        , group = model.groupLevel0ToAdd
        , selection = model.selectionLevel0ToAdd
        , cloning_technique = model.cloningTechniqueLevel0ToAdd
        , is_BsmB1_free = model.isBsmB1FreeLevel0ToAdd
        , notes = model.notesLevel0ToAdd
        , re_ase_digest = model.reAseDigestLevel0ToAdd
        , sequence = model.sequenceLevel0ToAdd
        , annotations = model.annotationsLevel0ToAdd
        , features = model.featuresLevel0ToAdd
        , references = model.referencesLevel0ToAdd
        }


makeOverhangOptions : List Overhang -> List (Input.Option Overhang msg)
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
constructLevel2View _ =
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
            [ Font.size 11
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
                    [ mainView model
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
            List.map showOverhang <| List.map .bsa1_overhang model.selectedInserts

        insertNames =
            List.map .name model.selectedInserts

        insertLengths =
            List.map (String.length << .sequence) model.selectedInserts

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
            sortByWith .bsa1_overhang ascending insertRecordList

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
            [ Html.button [ onClick ResetInsertList, HA.style "margin-right" "75px", HA.style "padding" "10px", HA.style "background-color" "white", HA.style "border-radius" "6px", HA.style "border" "solid 3px rgb(152, 171, 198)" ] [ Html.text "Reset Level0 List" ]
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
        makeButton position bsa1_overhang =
            Input.optionWith bsa1_overhang <| button position <| showOverhang bsa1_overhang
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
                -- { data = List.filter(filterLevel0 model.level0FilterString) <| model.insertList
                -- { data = List.filter(filterLevel0OnOverhang (showOverhang model.currOverhang) model.insertList
                { data = model.insertList |> List.filter (filterLevel0OnOverhang model.currOverhang) |> List.filter (filterLevel0 model.level0FilterString)
                , columns =
                    [ { header = none
                      , width = fillPortion 3
                      , view = .mPG0Number >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 5
                      , view =
                            \level0 ->
                                Input.button [ Font.color color.blue, Font.bold, Font.underline ] { onPress = Just (AppendInsert level0), label = Element.text level0.name }
                      }
                    , { header = none
                      , width = fillPortion 1
                      , view = .sequence >> String.length >> String.fromInt >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 1
                      , view = .bsa1_overhang >> showOverhang >> Element.text >> el [ centerY ]
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
            if not (List.member newInsert.bsa1_overhang (List.map .bsa1_overhang model.selectedInserts)) then
                ( { model
                    | selectedInserts = List.append model.selectedInserts [ newInsert ]
                    , constructLength = List.sum (model.selectedBackbone.length :: String.length newInsert.sequence :: List.map (.sequence >> String.length) model.selectedInserts)
                  }
                , Cmd.none
                )

            else
                ( { model
                    | selectedInserts = newInsert :: List.filter (\level0 -> not (level0.bsa1_overhang == newInsert.bsa1_overhang)) model.selectedInserts
                    , constructLength = List.sum (model.selectedBackbone.length :: List.map (.sequence >> String.length) (newInsert :: List.filter (\level0 -> not (level0.bsa1_overhang == newInsert.bsa1_overhang)) model.selectedInserts))
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
            ( { model | backboneGenbankContent = Just content }, Cmd.none )

        AddLevel0 newIns ->
            ( { model | insertList = newIns :: model.insertList }, Cmd.none )

        ChangeLevel0NameToAdd name ->
            ( { model | nameLevel0ToAdd = name }, Cmd.none )

        ChangeLevel0MpgNumberToAdd mpg0Number ->
            ( { model | mpg0NumberLevel0ToAdd = mpg0Number }, Cmd.none )

        ChangeLevel0OverhangToAdd bsa1_overhang ->
            ( { model | bsa1OverhangLevel0ToAdd = Just bsa1_overhang }, Cmd.none )

        GBNewLevel0Requested ->
            ( model, Select.file [ "text" ] GBNewLevel0Selected )

        GBNewLevel0Selected file ->
            ( model, Task.perform GbNewLevel0Loaded (File.toString file) )

        GbNewLevel0Loaded content ->
            ( { model | level0GenbankContent = Just content }, Cmd.none )

        Level0Received (Ok level0s) ->
            ( { model | insertList = level0s }, Cmd.none )

        Level0Received (Err _) ->
            ( model, Cmd.none )

        RequestAllLevel0 ->
            ( model, authenticatedGet (Maybe.withDefault "" model.token) "http://localhost:8000/vectors/level0" Level0Received (Decode.list level0Decoder) )



-- Filter functions


filterBackbone : Maybe String -> Backbone -> Bool
filterBackbone needle val =
    case needle of
        Nothing ->
            True

        Just ndle ->
            String.contains ndle val.name || String.contains ndle val.mPGBNumber


filterLevel0 : Maybe String -> Level0 -> Bool
filterLevel0 needle val =
    case needle of
        Nothing ->
            True

        Just ndle ->
            String.contains ndle val.name || String.contains ndle val.mPG0Number


filterLevel0OnOverhang : Overhang -> Level0 -> Bool
filterLevel0OnOverhang needle val =
    needle == val.bsa1_overhang



-- End Filter functions


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


annotationDecoder : Decode.Decoder Annotation
annotationDecoder =
    Decode.map2 Annotation
        (Decode.field "key" Decode.string)
        (Decode.field "value" Decode.string)


featureDecoder : Decode.Decoder Feature
featureDecoder =
    Decode.succeed Feature
        |> JDP.required "type" Decode.string
        |> JDP.required "qualifiers" (Decode.list qualifierDecoder)
        |> JDP.required "start_pos" Decode.int
        |> JDP.required "end_pos" Decode.int
        |> JDP.required "strand" Decode.int


qualifierDecoder : Decode.Decoder Qualifier
qualifierDecoder =
    Decode.map2 Qualifier
        (Decode.field "key" Decode.string)
        (Decode.field "value" Decode.string)


referenceDecoder : Decode.Decoder Reference
referenceDecoder =
    Decode.map2 Reference
        (Decode.field "authors" Decode.string)
        (Decode.field "title" Decode.string)


type IsPresent
    = Yes
    | No
    | Unknown


level0Decoder : Decode.Decoder Level0
level0Decoder =
    let
        str2IsPresent : String -> IsPresent
        str2IsPresent s =
            case String.toLower s |> String.trim of
                "yes" ->
                    Yes

                "no" ->
                    No

                _ ->
                    Unknown

        decodeOverhang : String -> Decode.Decoder Overhang
        decodeOverhang str =
            case stringToOverhang (String.trim str) of
                Just oh ->
                    Decode.succeed oh

                _ ->
                    Decode.fail "Not a valid overhang"
    in
    Decode.succeed Level0
        |> JDP.required "name" Decode.string
        |> JDP.required "id" (Decode.int |> Decode.map String.fromInt)
        |> JDP.required "bsa1_overhang" (Decode.string |> Decode.andThen decodeOverhang)
        |> JDP.required "bacterial_strain" Decode.string
        |> JDP.required "responsible" Decode.string
        |> JDP.required "group" Decode.string
        |> JDP.required "selection" Decode.string
        |> JDP.required "cloning_technique" Decode.string
        |> JDP.optional "is_BsmB1_free" (Decode.string |> Decode.map str2IsPresent) Unknown
        |> JDP.optional "notes" (Decode.maybe Decode.string) Nothing
        |> JDP.required "REase_digest" Decode.string
        |> JDP.required "sequence" Decode.string
        |> JDP.required "annotations" (Decode.list annotationDecoder)
        |> JDP.required "features" (Decode.list featureDecoder)
        |> JDP.required "references" (Decode.list referenceDecoder)



-- Login & Authentication functions


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



-- End Login & Authentication functions


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
showOverhang bsa1_overhang =
    case bsa1_overhang of
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
        "AB" ->
            Just A__B

        "BC" ->
            Just B__C

        "CD" ->
            Just C__D

        "CG" ->
            Just C__G

        "DE" ->
            Just D__E

        "DG" ->
            Just D__G

        "EF" ->
            Just E__F

        "EG" ->
            Just E__G

        "FG" ->
            Just F__G

        _ ->
            Nothing
