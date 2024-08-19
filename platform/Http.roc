module [
    Request,
    Method,
    Header,
    TimeoutConfig,
    Response,
    Err,
    header,
    handleStringResponse,
    defaultRequest,
    errorToString,
    send,
    get,
]

import Effect
import InternalTask
import Task exposing [Task]
import InternalHttp

## Represents an HTTP request.
Request : InternalHttp.Request

## Represents an HTTP method.
Method : InternalHttp.Method

## Represents an HTTP header e.g. `Content-Type: application/json`
Header : InternalHttp.Header

## Represents a timeout configuration for an HTTP request.
TimeoutConfig : InternalHttp.TimeoutConfig

## Represents an HTTP response.
Response : {
    url : Str,
    statusCode : U16,
    statusText : Str,
    headers : List Header,
    body : List U8,
}

## Represents an HTTP error.
Err : InternalHttp.Error

## A default [Request] value.
##
## ```
## # GET "roc-lang.org"
## { Http.defaultRequest &
##     url: "https://roc-lang.org",
## }
## ```
##
defaultRequest : Request
defaultRequest = {
    method: Get,
    headers: [],
    url: "",
    mimeType: "",
    body: [],
    timeout: NoTimeout,
}

## An HTTP header for configuring requests.
##
## See common headers [here](https://en.wikipedia.org/wiki/List_of_HTTP_header_fields).
header : Str, Str -> Header
header =
    Header

## Map a [Response] body to a [Str] or return an [Err].
handleStringResponse : Response -> Result Str Err
handleStringResponse = \response ->
    response.body
    |> Str.fromUtf8
    |> Result.mapErr \BadUtf8 _ pos ->
        position = Num.toStr pos

        BadBody "Invalid UTF-8 at byte offset $(position)"

## Convert an [Err] to a [Str].
errorToString : Err -> Str
errorToString = \err ->
    when err is
        BadRequest e -> "Invalid Request: $(e)"
        Timeout ms -> "Request timed out after $(Num.toStr ms) ms."
        NetworkError -> "Network error."
        BadStatus code -> "Request failed with status $(Num.toStr code)."
        BadBody details -> "Request failed: Invalid body: $(details)"

## Task to send an HTTP request, succeeds with a value of [Str] or fails with an
## [Err].
##
## ```
## # Prints out the HTML of the Roc-lang website.
## response =
##     Http.send! { Http.defaultRequest &
##         url: "https://www.roc-lang.org"
##     }
##
## response.body
## |> Str.fromUtf8
## |> Result.withDefault "Invalid UTF-8"
## |> Stdout.line!
## ```
send : Request -> Task Response [HttpErr Err]
send = \req ->
    # TODO: Fix our C ABI codegen so that we don't this Box.box heap allocation
    Effect.sendRequest (Box.box req)
    |> Effect.map Ok
    |> InternalTask.fromEffect
    |> Task.await \internalResponse ->
        when internalResponse is
            BadRequest str -> Task.err (BadRequest str)
            Timeout u64 -> Task.err (Timeout u64)
            NetworkError -> Task.err NetworkError
            BadStatus meta _ -> Task.err (BadStatus meta.statusCode)
            GoodStatus meta body ->
                Task.ok {
                    url: meta.url,
                    statusCode: meta.statusCode,
                    statusText: meta.statusText,
                    headers: meta.headers,
                    body,
                }
    |> Task.mapErr HttpErr

## Task to send an HTTP GET request and decode the response body.
##
## This function combines sending a GET request with decoding the response body.
## It returns a [Task] that succeeds with the decoded body or fails with either
## an [HttpErr] or [HttpDecodingFailed].
##
## ```
## # Get and decode a JSON response
## jsonResponse =
##     Http.get! "https://api.example.com/data" Json.utf8
##
## when jsonResponse is
##     Ok data -> handleData data
##     Err (HttpErr err) -> handleHttpError err
##     Err HttpDecodingFailed -> handleDecodingError
## ```
##
## @param url - The URL to send the GET request to
## @param fmt - The decoder format to use for decoding the response body
get : Str, fmt -> Task body [HttpErr Http.Err, HttpDecodingFailed] where body implements Decoding, fmt implements DecoderFormatting
get = \url, fmt ->
    response = send! { defaultRequest & url }

    Decode.fromBytes response.body fmt
    |> Result.mapErr \_ -> HttpDecodingFailed
    |> Task.fromResult
