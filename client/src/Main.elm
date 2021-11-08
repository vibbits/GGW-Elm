module Main exposing (..)

import Array exposing (Array, length)
import Browser
import Browser.Dom exposing (Error(..))
import Color
import Debug exposing (toString)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border exposing (rounded)
import Element.Font as Font
import Element.Input as Input exposing (OptionState(..))
import Element.Region
import Html exposing (Html, label)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import List
import Path
import Shape exposing (defaultPieConfig)
import TypedSvg exposing (g, svg, text_)
import TypedSvg.Attributes exposing (dy, stroke, textAnchor, transform, viewBox)
import TypedSvg.Core exposing (Svg)
import TypedSvg.Types exposing (AnchorAlignment(..), Paint(..), Transform(..), em)


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
    }


type alias Insert =
    { name : String, mPG0Number : String, overhang : Overhang, length : Int }


testInsertList : List Insert
testInsertList =
    [ { name = "Insert 1", mPG0Number = "MPG-G0-000001", overhang = A__B, length = 501 }
    , { name = "Insert 2", mPG0Number = "MPG-G0-000007", overhang = B__C, length = 402 }
    , { name = "Insert 3", mPG0Number = "MPG-G0-000002", overhang = C__D, length = 303 }
    , { name = "Insert 4", mPG0Number = "MPG-G0-000006", overhang = D__E, length = 404 }
    , { name = "Insert 5", mPG0Number = "MPG-G0-000003", overhang = E__F, length = 505 }
    , { name = "Insert 6", mPG0Number = "MPG-G0-000005", overhang = F__G, length = 606 }
    ]


type alias Backbone =
    { name : String, mPGBNumber : String, level : Int, length : Int }


testBackbone : Backbone
testBackbone =
    { name = "Current Backbone"
    , mPGBNumber = "MPG-B-000035"
    , level = 1
    , length = 5624
    }



-- Model


init : ( Model, Cmd Msg )
init =
    ( { currApp = Standard
      , currOverhang = A__B
      , numberInserts = 6
      , backboneLevel = 1
      , overhangShape = overhangList6
      , constructName = "Demo Construct"
      , constructNumber = "MP-G1-000000001"
      , constructLength = 20000
      , applicationNote = "Some Application: words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words"
      , designerName = "Guy, Smart"
      , description = "Some Description: words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words words"
      , selectedInserts = testInsertList
      , selectedBackbone = testBackbone
      }
    , Cmd.none
    )


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
    = ChooseApplication Application
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



-- view


view : Model -> Html Msg
view model =
    layout
        [ -- Element.explain Debug.todo -- Adds debugging info to the console.
          Font.size 11
        , inFront <| navLinks
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
                    Element.text "Level 1 construct design"
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
                    , el [ Background.color color.lightGrey, padding 10 ] <| Element.text (toString model.constructLength)
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
                , backboneTable model
                , applicationRadioButton model
                , overhangRadioRow model
                , insertTable model
                , downloadButtonBar
                , Element.html <| visualRepresentation model
                ]
            ]



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
pieSlice index datum =
    Path.element (Shape.arc datum) [ TypedSvg.Attributes.fill <| Paint <| Maybe.withDefault Color.darkCharcoal <| Array.get index chartColors, stroke <| Paint Color.white ]


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


visualRepresentation : Model -> Html Msg
visualRepresentation model =
    let
        -- Note: The reversing is for making sure insert 1 is at position 0. This way the destination vector is appended on the back of the list!
        chartLabels =
            List.reverse (model.selectedBackbone.name :: List.reverse (List.map .name model.selectedInserts))

        chartLengths =
            List.reverse (List.map toFloat <| model.selectedBackbone.length :: List.reverse (List.map .length model.selectedInserts))

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
            , Html.button [ onClick ResetBackbone, style "margin-left" "75px", style "padding" "10px", style "background-color" "white", style "border-radius" "6px", style "border" "solid 3px rgb(152, 171, 198)" ] [ Html.text "Reset Backbone" ]
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
            , padding 25
            , clipY
            ]
            [ el ((Element.width <| fillPortion 5) :: headerAttrs) <| Element.text "Insert Name"
            , el ((Element.width <| fillPortion 3) :: headerAttrs) <| Element.text "MP-G0-Number"
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
                , padding 50
                ]
                { data = insertList model.currOverhang
                , columns =
                    [ { header = none
                      , width = fillPortion 5
                      , view =
                            \insert ->
                                Input.button [ Font.color color.blue, Font.bold, Font.underline ] { onPress = Just (AppendInsert insert), label = Element.text insert.name }
                      }
                    , { header = none
                      , width = fillPortion 3
                      , view = .mPG0Number >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 1
                      , view = .length >> toString >> Element.text >> el [ centerY ]
                      }
                    ]
                }
        ]


backboneTable : Model -> Element Msg
backboneTable model =
    let
        -- _ =
        --     Debug.log "Debug says: " overhangList4

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
            , padding 25
            ]
            [ el ((Element.width <| fillPortion 5) :: headerAttrs) <| Element.text "Backbone Name"
            , el ((Element.width <| fillPortion 3) :: headerAttrs) <| Element.text "MP-GB-Number"
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
                , padding 50
                ]
                { data = backboneList model.backboneLevel
                , columns =
                    [ { header = none
                      , width = fillPortion 5
                      , view =
                            \backbone ->
                                Input.button [ Font.color color.blue, Font.bold, Font.underline ] { onPress = Just (ChangeBackbone backbone), label = Element.text backbone.name }
                      }
                    , { header = none
                      , width = fillPortion 3
                      , view = .mPGBNumber >> Element.text >> el [ centerY ]
                      }
                    , { header = none
                      , width = fillPortion 1
                      , view = .length >> toString >> Element.text >> el [ centerY ]
                      }
                    ]
                }
        ]



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        -- _ = Debug.log "Some String" msg
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
            ( { model | selectedInserts = List.append model.selectedInserts [ newInsert ] }, Cmd.none )

        ChangeBackbone newBackbone ->
            ( { model | selectedBackbone = newBackbone }, Cmd.none )

        ResetInsertList ->
            ( { model | selectedInserts = [] }, Cmd.none )

        ResetBackbone ->
            ( { model | selectedBackbone = { name = "", length = 0, mPGBNumber = "", level = 0 } }, Cmd.none )


main : Program () Model Msg
main =
    Browser.element
        { init = always init
        , subscriptions = always Sub.none
        , view = view
        , update = update
        }
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
