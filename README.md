# zfcore
zfcore is high performance http server and web framework for nim lang
we replace asynchttpserver with zfblast server https://github.com/zendbit/nim.zfblast

# Web Socket (yeah)
from version 1.0.6 already support web socket

# Install from nimble
```
use develop mode for the latest version:
nimble develop zfcore

or use the nimble version but not guarantee point to the latest version:
nimble install zfcore
```

# usage
Example code, this is example code from web template of zendflow, for zendflow usage follow this link https://github.com/zendbit/zendflow
```
#[
  zfcore web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#

#[
  This module auto export from zendFlow module
  export
    HttpContext, -> zfcore module
    router, -> zfcore module
    Router, -> zfcore module
    route, -> zfcore module
    Route, -> zfcore module
    asyncdispatch, -> stdlib module
    zfblast, -> zf blast implementation of async http server with openssl
    tables, -> stdlib module
    formdata, -> zfcore module
    strtabs, -> stdlib module
    uri3, -> nimble package
    strutils, -> stdlib module
    times, -> stdlib module
    os, -> stdlib module
    Settings, -> zfcore module
    settings, -> zfcore module
    AsyncSocket, -> stdlib module
    asyncnet -> stdlib module
    zfplugs -> zfcore plugins
    stdext -> nim extended standard library
    zfmacros -> zfcore macros helper
]#

import zfcore, example

#
# configuration:
# copy settings.json.example as settings.json
#

# this is the new fashion of the zendflow framework syntax, make it easy
# and reduce defining multiple time of callback procedures
# this new syntax not break the old fashion, we only add macros and modify the syntax
# on compile time
#
#
# Some Important note
# inside routes
# routes:
#   get "/hello":
#     # in here we can call HttpContext
#     # HttpContext is unique object that heandle client request and response
#     # HttpContext containts:
#     # ws (WebSocket):
#     #   ws is ctx.webSocket shorthand
#     # req (Request):
#     #   req is ctx.request shorthand
#     # res (Response):
#     #   res is ctx.response shorthand
#     # params (table[string, string]):
#     #   params is ctx.params shorthand
#     #   this will contains data request parameter from client
#     #   - key value of query string
#     #   - key value of form url encoded
#     # reParams (table[string, @[string]]):
#     #   reParams is ctx.reParams shorthand
#     #   this will contains pattern matching on the url segments
#     # formData (FormData):
#     #   formData is ctx.formData shorthand
#     #   this will handle form data multipart including uploaded data
#     # json (JsonNode):
#     #   json is ctx.json shorthand
#     #   this will handle application/json request from client
#     
#
#     # you can response to client with following type response:
#     # HttpCode.resp("body response", httpheaders)
#     # HttpCode is HttpCode value from the nim httpcore standard library
#     # for example we want to reponse with Http200
#     # Http200.resp("Hello World")
#     # 
#     # the default response type is text/plain
#     # for html response use
#     # Http200.respHtml("This is html content")
#     #
#     # for json response you only need to pas JsonNode object to the resp
#     # Http200.resp(%*{"Hello": "World"})
#     #
#     # for send redirection web can use respRedirect
#     # Http200.respRedirect("https://google.com")
#     #
#
#
routes:
  # websocket example :-)
  get "/ws":
    #
    # ctx instance of HttpCtx exposed here :-)
    # ws is shorthand of ctx.websocket
    #
    if not ws.isNil:
      case ws.state:
      of WSState.HandShake:
        echo "HandShake state"
        # this state will evaluate
        # right before handshake process
        # in here we can add the additionals response headers
        # normaly we can skip this step
        # about the handshake:
        # handshake is using http headers
        # this process is only happen 1 time
        # after handshake success then the protocol will be switch to the websocket
        # you can check the handshake header request in
        # -> ws.handShakeReqHeaders this is the HtttpHeaders type
        # and you also can add the additional headers information in the response handshake
        # by adding the:
        # -> ws.handShakeResHeaders
      of WSState.Open:
        echo "Open state"
        # in this state all swaping process will accur
        # like send or received message
        case ws.statusCode:
        of WSStatusCode.Ok:
          case ws.inFrame.opCode:
          of WSOpCode.TextFrame.uint8:
            echo "Text frame received"
            echo &"Fin {ws.inFrame.fin}"
            echo &"Rsv1 {ws.inFrame.rsv1}"
            echo &"Rsv2 {ws.inFrame.rsv2}"
            echo &"Rsv3 {ws.inFrame.rsv3}"
            echo &"OpCode {ws.inFrame.opCode}"
            echo &"Mask {ws.inFrame.mask}"
            echo &"Mask Key {ws.inFrame.maskKey}"
            echo &"PayloadData {ws.inFrame.payloadData}"
            echo &"PayloadLen {ws.inFrame.payloadLen}"
            # how to show decoded data
            # we can use the encodeDecode
            echo ""
            echo "Received data (decoded):"
            echo ws.inFrame.encodeDecode()
            # let send the data to the client
            # set fin to 1 if this is independent message
            # 1 meaning for read and finish
            # if you want to use continues frame
            # set it to 0
            # for more information about web socket frame and protocol
            # refer to the web socket documentation ro the RFC document
            #
            # WSOpCodeEnum:
            # WSOpCode* = enum
            #    ContinuationFrame = 0x0
            #    TextFrame = 0x1
            #    BinaryFrame = 0x2
            #    ConnectionClose = 0x8
            ws.outFrame = newWSFrame(
              "This is from the endpoint :-)",
              1,
              WSOpCode.TextFrame.uint8)
            await ws.send()
          of WSOpCode.BinaryFrame.uint8:
            echo "Binary frame received"
          of WSOpCode.ContinuationFrame.uint8:
            # the frame continues from previous frame
            echo "Continuation frame received"
          of WSOpCode.ConnectionClose.uint8:
            echo "Connection close frame received"
          else:
              discard
        else:
            echo &"Failed status code {ws.statusCode}"
      of WSState.Close:
        echo "Close state"
        # this state will execute if the connection close


  # this static route wil serve under
  # all static resource will serve under / uri path
  # address:port/
  # example address:port/style/*.css
  # if you custumize the static route for example zf.r.static("/public")
  # it will serve with address:port/public/
  # we can retrieve using address:port/public/style/*.css
  staticDir "/"

  # using regex for matching the request
  # the regex is regex match like in pcre standard like regex on python, perl etc
  # <ids:re[([0-9]+)_([0-9]+)]>
  # - the ids wil capture as parameter name
  # - the len[2] is for len for capturing in this case in the () bracket,
  #   will capture ([0-9]+) twice
  # - if only want to capture one we must exactly match len[n]
  #   with number of () capturing bracket
  # - capture regex will return list of match and can be access using ctx.reParams
  # - if we want to capture segment parameter we can use <param_to_capture>
  #   in this case we use <name>
  # - <name> will capture segment value in there as name,
  #   we can access param value and query string in HttpCtx.params["name"] or other param name
  get "/home/<ids:re[([0-9]+)_([0-9]+)]>/<name>":
    echo "Welcome home"
    # capture regex result from the url
    echo reParams["ids"]
    # capture <name> value parameter from the url
    echo params["name"]
    # we can also set custom header for the response
    # using ctx.responseHeaders.add("header kye", "header value")
    res.headers.add("Content-Type", "text/plain")
    Http200.respHtml("Hello World get request")

  #get "/home/<id>/<name>":
  #  echo ctx.params["name"]
  #  echo ctx.params["id"]
  #  resp(Http200, "Ok")

  # accept request with /home/123456
  # id will capture the value 12345
  post "/home/<id>":
    # if we post as application url encoded, the field data key value will be in the ctx.params
    # we can access using ctx.params["the name of the params"]
    # if we post as multipars we can capture the form field and files uploded in ctx.formData
    # - access field form data using ctx.formData.getField("fieldform_name")
    #   will return FieldData object
    # - access file form data using ctx.formData.getFileByName("name")
    #   will return FileData object
    # - access file form data using ctx.formData.getFileByFilename("file_name")
    #   will return FileData object
    # - all uploded file will be in the tmp dir for default,
    #   you can move the file to the destination file or dir by call
    # - let uploadedFile = ctx.formData.getFileByFilename("file_name")
    # - if not isNil(uploadedFile): uploadedFile.moveFileTo("the_destination_file_with_filename")
    # - if not isNil(uploadedFile): uploadedFile.moveFileToDir("the_destination_file_to_dir")
    # - or we can iterate the field
    #       for field in ctx.formData.getFields():
    #           echo field.name
    #           echo field.contentDisposition
    #           echo field.content
    # - also capture uploaded file using
    #       for file in ctx.formData.getFiles():
    #           echo file.name
    #           echo file.contentDisposition
    #           echo file.content -> is absolute path of the file in tmp folder
    #           echo file.filename
    #           echo file.contentType
    #
    #  - for more information you can also check documentation form the source:
    #       zfCore/zf/HttpCtx.nim
    #       zfCore/zf/formData.nim
    #
    # capture the <id> from the path
    echo params["id"]
    Http200.respHtml(HelloWorld().printHelloWorld)

  patch "/home/<id>":
    # capture the <id> from the path
    echo params["id"]
    Http200.resp("Hello World patch request")

  delete "/home/<id>":
    # capture the <id> from the path
    echo params["id"]
    Http200.resp("Hello World delete request")

  put "/home/<id>":
    # capture the <id> from the path
    echo params["id"]
    Http200.resp("Hello World put request")

  head "/home/<id>":
    # capture the <id> from the path
    echo params["id"]
    Http200.resp("Hello World head request")

  # before Route here
  # you can filter the context request here before route happen
  # use full if we want to filtering the domain access or auth or other things that fun :-)
  # make sure if call response directly from middleware
  # require call return true for breaking the pipeline:
  #   resp(Http404, "page not found"))
  #   return true
  before:
    # ctx instance of HttpCtx exposed here :-)
    #
    echo "before route"

  # after Route here
  # you can filter the context request here after route happen
  # use full if we want to filtering the domain access or auth or other things that fun :-)
  # make sure if call response directly from middleware
  # require call return true for breaking the pipeline:
  #   resp(Http404, "page not found"))
  #   return true
  after:
    # ctx instance of HttpCtx exposed here :-)
    # route instance of Route exposed here :-)
    #
    echo "Hello World"
```

Some method from ctx we wrapped in the routes
```
ctx.resp -> resp
ctx.respRedirect -> respRedirect
ctx.setCookie -> setCookie
ctx.getCookie -> getCookie
ctx.clearCookie -> clearCookie
```

Configuration file create file settings.json in the same level with the source
```
{
  "keepAliveMax": 100,
  "keepAliveTimeout": 15,
  "maxBodyLength": 268435456,
  "readBodyBuffer": 51200,
  "responseRangeBuffer": 51200,
  "maxResponseBodyLength": 52428800,
  "trace": false,
  "http": {
    "port": 8080,
    "address": "0.0.0.0",
    "reuseAddress": true,
    "reusePort": false,
    "secure": {
      "cert": "ssl/certificate.pem",
      "key": "ssl/key.pem",
      "verify": true,
      "port": 8443
    }
  },
  "database": {
    "pgsql": {
      "host": "127.0.0.1",
      "port": 5432,
      "username": "admin",
      "password": "secret",
      "database": "mydb"
    }
  },
  "auth": {
    "basicAuth": {
      "username": "foo",
      "password": "bar"
    }
  }
}
```

## Fluent validation

Starting from version 1.0.1 we added fluent validation

```
let validation = newFluentValidation()
  validation
    .add(newFieldData("username", ctx.params["username"])
      .must("Username is required.")
      .reMatch("([\w\W]+@[\w\W]+\.[\w])$", "Email format is not valid."))
    .add(newFieldData("password", ctx.params["password"])
      .must("Password is required.")
      .rangeLen(10, 255, "Min password length is 10, max is 255."))
            
access the validation result:
  validation.valids -> contain valids field on validation (JsonNode)
  validation.notValids -> contain notValids field on validation (JsonNode)
```

with new macro we can transform the validation using this (make it easy to understand maybe :-)):

```
let validation = fluentValidation:
  data "username" params.getOrDefault("username"):
    must:
      err "Username is required."
      ok "Username available."
    reMatch "([\w\W]+@[\w\W]+\.[\w])$":
      err "Email format is not valid."
  data "password" params.getOrDefault("password"):
    must:
      err "Password is required."
    rangeLen 10 255:
      err "Min password length is 10, max is 255."
      
if validation.isValid:
  echo validation.valids.pretty(2)
else:
  echo validation.notValids.pretty(2)
```

Fluent Validation containts this procedures for validation each FieldData:
1. must(errMsg: string = "your err msg", okMsg: string = "your ok msg")
will return errMsg if value empty
2. num(errMsg: string = "your err msg", okMsg: string = "your ok msg")
will return errMsg if value not a number
3. rangeNum(min: float64, max: float64, errMsg: string = "your errMsg", okMsg: string = "your ok msg")
will return errMsg if the number not in the range (min - max)
4. minNum(min: float64, errMsg: string = "your errMsg", okMsg: string = "your ok msg")
will return errMsg if the value less than min
5. maxNum(max: float64, errMsg: string = "your errMsg", okMsg: string = "your ok msg")
will return errMsg if the value larger than max
6. minLen(min: int, errMsg: string = "your errMsg", okMsg: string = "your ok msg")
will return errMsg if value length less than min
7. maxLen(max: int, errMsg: string = "your errMsg", okMsg: string = "your ok msg")
will return errMsg if value length more than max
8. rangeLen(min: int, max: int, errMsg: "your errMsg", okMsg: string = "your ok msg")
will return errMsg if value length not in range (min - max)
9. reMatch(regex: string, errMsg: string = "your errMsg", okMsg: string = "your ok msg")
will return errMsg if the value not match with regex match pattern
10. bool(errMsg: string = "your err msg", okMsg: string = "your ok msg")
will return errMsg if the value is not bool type

## Core structure

- zfCore

This folder contain zfcore engine. The zfcore folder contains .nim file of zendflow building block also contain folder unpure, the unpure folder will contains unpure lib (thirdparty library)

zfcore contains:
1. httpcontext.nim
this will handle request context also contains the response context
```
#[
    The field is widely used the asynchttpserver Request object but we add some field to its:
        url -> in ZendFlow we user uri3 from the nimble package
        params -> is table of the captured query string and path segment
        reParams -> is table of the captured regex match with the segment
        formData -> is FormData object and will capture if we use the multipart form
        json -> this will capture the application/json body from the post/put/patch method
        settings -> this is the shared settings
        request -> request context
        response -> response context
]#

type
    HttpContext* = ref object of zfblast.HttpContext
        params*: Table[string, string]
        reParams*: Table[string, seq[string]]
        formData*: FormData
        json*: JsonNode
        settings*: Settings
        
# Where zfblast.HttpContext is zfblast context
type
    HttpContext* = ref object of RootObj
        # Request type instance
        request*: Request
        # client asyncsocket for communicating to client
        client*: AsyncSocket
        # Response type instance
        response*: Response
        # send response to client, this is bridge to ZFBlast send()
        send*: proc (ctx: HttpContext): Future[void]
        # Keep-Alive header max request with given persistent timeout
        # read RFC (https://tools.ietf.org/html/rfc2616)
        # section Keep-Alive and Connection
        # for improving response performance
        keepAliveMax*: int
        # Keep-Alive timeout
        keepAliveTimeout*: int
```
2. formdata.nim

This will handle the formdata multipart and parse the form field and uploaded file

3. middleware.nim

This will handle the middleware of the engine, this contain before route and after route pipeline for filtering

4. mime.nim

This is database of mime file, not all mime file registered here, if the mime file not found then the mime will be application/octet-stream

5. route.nim

This file is model of the route

6. router.nim

This file will handle registered route, for example user register the get, put, push, patch, head, post, options method to the router.

7. settings.nim

This is the settings model for the zenflow application

9. zfcore.nim

The is the starting building block

Thats it, feel free to modify and pull request if you have any idea, also this is the public domain we can share or you can cantact me on my email [amru.rosyada@amil.com](amru.rosyada@amil.com) to discuss further.

This is production ready :-), feel free to send me a bug to solve.
