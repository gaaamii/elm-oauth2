module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Json
import Navigation
import OAuth
import OAuth.Implicit


---------------------------------------
-- Endpoints to interact with Google OAuth


authorizationEndpoint : String
authorizationEndpoint =
    "https://accounts.google.com/o/oauth2/v2/auth"


profileEndpoint : String
profileEndpoint =
    "https://www.googleapis.com/oauth2/v1/userinfo"



---------------------------------------
-- Basic Application Model


type alias Model =
    { oauth :
        { clientId : String
        , redirectUri : String
        }
    , error : Maybe String
    , token : Maybe OAuth.Token
    , profile : Maybe Profile
    }


type alias Profile =
    { email : String
    , name : String
    , picture : String
    }


profileDecoder : Json.Decoder Profile
profileDecoder =
    Json.map3 Profile
        (Json.field "email" Json.string)
        (Json.field "name" Json.string)
        (Json.field "picture" Json.string)



---------------------------------------
-- Messages for the app
--
-- Authorize -> Trigger an OAuth authorization call. The authentication is done implicitly


type Msg
    = Nop
    | Authorize
    | UpdateClientId String
    | GetProfile (Result Http.Error Profile)


main : Program Never Model Msg
main =
    Navigation.program
        (always Nop)
        { init = init
        , update = update
        , view = view
        , subscriptions = (\_ -> Sub.none)
        }



---------------------------------------
-- On init, we parse the location to find any trace of an OAuth redirection. We are looking
-- for an `authorization_code` here.
--
-- Also, since the `clientId` and `secret` aren't stored in the code to make this demo
-- interactive, we've also passed them along in the state (which is returned, untouched,
-- by the resource provider). In practice, you don't want to do this.


init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    let
        model =
            { oauth =
                { clientId = ""
                , redirectUri = location.origin ++ location.pathname
                }
            , error = Nothing
            , token = Nothing
            , profile = Nothing
            }
    in
        case OAuth.Implicit.parse location of
            Ok { token } ->
                let
                    req =
                        Http.request
                            { method = "GET"
                            , body = Http.emptyBody
                            , headers = OAuth.use token []
                            , withCredentials = False
                            , url = profileEndpoint
                            , expect = Http.expectJson profileDecoder
                            , timeout = Nothing
                            }
                in
                    { model | token = Just token }
                        ! [ Navigation.modifyUrl model.oauth.redirectUri
                          , Http.send GetProfile req
                          ]

            Err OAuth.Empty ->
                model ! []

            Err (OAuth.OAuthErr err) ->
                { model | error = Just <| OAuth.showErrCode err.error }
                    ! [ Navigation.modifyUrl model.oauth.redirectUri ]

            Err _ ->
                { model | error = Just "parsing error" } ! []



---------------------------------------
-- Update is pretty straightforward.


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ oauth } as model) =
    case msg of
        Nop ->
            model ! []

        UpdateClientId clientId ->
            let
                oauth_ =
                    { oauth | clientId = clientId }
            in
                { model | oauth = oauth_ } ! []

        GetProfile res ->
            case res of
                Err err ->
                    { model | error = Just "unable to fetch user profile ¯\\_(ツ)_/¯" } ! []

                Ok profile ->
                    { model | profile = Just profile } ! []

        Authorize ->
            model
                ! [ OAuth.Implicit.authorize
                        { clientId = model.oauth.clientId
                        , redirectUri = model.oauth.redirectUri
                        , responseType = OAuth.Token
                        , scope = [ "email", "profile" ]
                        , state = Nothing
                        , url = authorizationEndpoint
                        }
                  ]



---------------------------------------
-- The View. Sorry for this. Nothing interesting here.


view : Model -> Html Msg
view model =
    let
        isNothing maybe =
            case maybe of
                Nothing ->
                    True

                _ ->
                    False

        content =
            case ( model.token, model.profile ) of
                ( Nothing, Nothing ) ->
                    Html.form
                        [ onSubmit Authorize
                        , style
                            [ ( "flex-direction", "column" )
                            ]
                        ]
                        [ input
                            [ onInput UpdateClientId
                            , type_ "text"
                            , placeholder "clientId"
                            , value model.oauth.clientId
                            , style
                                [ ( "border", "none" )
                                , ( "border-bottom", "1px solid #757575" )
                                , ( "color", "#757575" )
                                , ( "font", "1.5em" )
                                , ( "font", "Roboto, Arial" )
                                , ( "outline", "none" )
                                , ( "padding", "0.5em 1em" )
                                , ( "text-align", "center" )
                                ]
                            ]
                            []
                        , button
                            [ style
                                [ ( "background", "url('/elm-oauth2/examples/images/google.png') 1em center no-repeat" )
                                , ( "background-size", "2em" )
                                , ( "border", "none" )
                                , ( "box-shadow", "rgba(0,0,0,0.25) 0px 2px 4px 0px" )
                                , ( "color", "#757575" )
                                , ( "font", "Roboto, Arial" )
                                , ( "margin", "1em" )
                                , ( "outline", "none" )
                                , ( "padding", "1em 1em 1em 3em" )
                                , ( "text-align", "right" )
                                ]
                            , onClick Authorize
                            ]
                            [ text "Sign in" ]
                        ]

                ( Just token, Nothing ) ->
                    div
                        [ style
                            [ ( "color", "#757575" )
                            , ( "font", "Roboto, Arial" )
                            , ( "text-align", "center" )
                            ]
                        ]
                        [ text "fetching profile..." ]

                ( _, Just profile ) ->
                    div
                        [ style
                            [ ( "display", "flex" )
                            , ( "flex-direction", "column" )
                            , ( "align-items", "center" )
                            ]
                        ]
                        [ img
                            [ src profile.picture
                            , style
                                [ ( "height", "150px" )
                                , ( "margin", "1em" )
                                , ( "width", "150px" )
                                ]
                            ]
                            []
                        , text <| profile.name ++ " <" ++ profile.email ++ ">"
                        ]
    in
        div
            [ style
                [ ( "display", "flex" )
                , ( "flex-direction", "column" )
                , ( "align-items", "center" )
                , ( "padding", "3em" )
                ]
            ]
            [ h2
                [ style
                    [ ( "display", "flex" )
                    , ( "font-family", "Roboto, Arial, sans-serif" )
                    , ( "color", "#141414" )
                    ]
                ]
                [ text "OAuth 2.0 Implicit Flow Example" ]
            , div
                [ style
                    [ ( "display"
                      , if isNothing model.error then
                            "none"
                        else
                            "block"
                      )
                    , ( "width", "100%" )
                    , ( "position", "absolute" )
                    , ( "top", "0" )
                    , ( "padding", "1em" )
                    , ( "font-family", "Roboto, Arial, sans-serif" )
                    , ( "text-align", "center" )
                    , ( "background", "#e74c3c" )
                    , ( "color", "#ffffff" )
                    ]
                ]
                [ text <| Maybe.withDefault "" model.error ]
            , content
            ]
