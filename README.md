# zfcore
zfcore is high performance asynchttpserver and web framework for nim lang

# Install from nimble
```
nimble install zfcore
```

# usage
```
#[
    ZendFlow web framework for nim language
    This framework if free to use and to modify
    License: BSD
    Author: Amru Rosyada
    Email: amru.rosyada@gmail.com
    Git: https://github.com/zendbit
]#

#[
    This module auto export from zendFlow module
    export
        ctxReq, -> zfcore module
        CtxReq, -> zfcore module
        router, -> zfcore module
        Router, -> zfcore module
        route, -> zfcore module
        Route, -> zfcore module
        asyncdispatch, -> stdlib module
        asynchttpserver, -> stdlib module
        tables, -> stdlib module
        formData, -> zfcore module
        FormData, -> zfcore module
        packedjson, -> zfcore module (unpure)
        strtabs, -> stdlib module
        uri3, -> nimble package
        strutils, -> stdlib module
        times, -> stdlib module
        os, -> stdlib module
        Settings, -> zfcore module
        settings, -> zfcore module
        AsyncSocket, -> stdlib module
        asyncnet -> stdlib module
]#

import zfcore/zendFlow

# increase the maxBody to handle large upload file
# value in bytes
let zf = newZendFlow(
    newSettings(
        appRootDir = getCurrentDir(),
        port = 8080,
        address = "0.0.0.0",
        reuseAddr = true,
        reusePort = false,
        maxBody = 8388608))

# handle before route middleware
zf.r.beforeRoute(proc (ctx: CtxReq): Future[bool] {.async.} =
    # before Route here
    # you can filter the context request here before route happen
    # use full if we want to filtering the domain access or auth or other things that fun :-)
    # make sure if call response directly from middleware must be call return true for breaking the pipeline:
    #   await ctx.resp(Http200, "Hello World get request"))
    #   return true
    )

# handle after route middleware
# this will execute right before dynamic route response to the server
zf.r.afterRoute(proc (ctx: CtxReq, route: Route): Future[bool] {.async.} =
    # after Route here
    # you can filter the context request here after route happen
    # use full if we want to filtering the domain access or auth or other things that fun :-)
    # make sure if call response directly from middleware must be call return true for breaking the pipeline:
    #   await ctx.resp(Http200, "Hello World get request"))
    #   return true
    )

# this static route wil serve under
# all static resource will serve under / uri path
# address:port/
# example address:port/style/*.css
# if you custumize the static route for example zf.r.static("/public")
# it will serve with address:port/public/
# we can retrieve using address:port/public/style/*.css
zf.r.static("/")

# using regex for matching the request
# the regex is regex match like in pcre standard like regex on python, perl etc
# <ids:re[([0-9]+)_([0-9]+)]:len[2]>
# - the ids wil capture as parameter name
# - the len[2] is for len for capturing in this case in the () bracket, will capture ([0-9]+) twice
# - if only want to capture one we must exactly match len[n] with number of () capturing bracket
# - capture regex will return list of match and can be access using ctx.reParams
# - if we want to capture segment parameter we can use <param_to_capture> in this case we use <name>
# - <name> will capture segment value in there as name, we can access param value and query string in ctxReq.params["name"] or other param name
zf.r.get("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<name>", proc (
        ctx: CtxReq): Future[void] {.async.} =
    echo "Welcome home"
    # capture regex result from the url
    echo ctx.reParams["ids"]
    # capture <name> value parameter from the url
    echo ctx.params["name"]
    # we can also set custom header for the response using ctx.responseHeaders.add("header kye", "header value")
    ctx.responseHeaders.add("Content-Type", "text/plain")
    await ctx.resp(Http200, "Hello World get request"))

zf.r.get("/", proc (
        ctx: CtxReq): Future[void] {.async.} =
    # set cookie
    let cookie = {"age": "25", "user": "john"}.newStringTable

    # cookie also has other parameter:
    # domain: string = "" -> default
    # path: string = "" -> default
    # expires: string = "" -> default
    # secure: bool = false -> default
    ctx.setCookie(cookie)

    # get coockie value:
    #   var cookie = ctx.getCookie() -> will return StringTableRef. Read nim strtabs module
    #   var age = cookie.getOrDefault("age")
    #   var user = cookie.getOrDefault("user")

    # if you want to clear the cookie you need to retrieve the cookie then pass the result to the clear cookie
    # clear cookie:
    #   var cookie = ctx.getCookie()
    #   ctx.clearCookie(cookie)

    # set default to redirect to index.htmo
    await ctx.respRedirect("/index.html"))

# accept request with /home/123456
# id will capture the value 12345
zf.r.post("/home/<id>", proc (ctx: CtxReq): Future[void] {.async.} =
    # if we post as application url encoded, the field data key value will be in the ctx.params
    # we can access using ctx.params["the name of the params"]
    # if we post as multipars we can capture the form field and files uploded in ctx.formData
    # - access field form data using ctx.formData.getField("fieldform_name") will return FieldData object
    # - access file form data using ctx.formData.getFileByName("name") will return FileData object
    # - access file form data using ctx.formData.getFileByFilename("file_name") will return FileData object
    # - all uploded file will be in the tmp dir for default, you can move the file to the destination file or dir by call
    # - let uploadedFile = ctx.formData.getFileByFilename("file_name")
    # - if not isNil(uploadedFile): uploadedFile.moveFileTo("the_destination_file_with_filename")
    # - if not isNil(uploadedFile): uploadedFile.moveFileToDir("the_destination_file_to_dir")
    # - or we can iterate the field
    #       for field in ctx.getFields():
    #           echo field.name
    #           echo field.contentDisposition
    #           echo field.content
    # - also capture uploaded file using
    #       for file in ctx.getFiles():
    #           echo file.name
    #           echo file.contentDisposition
    #           echo file.content -> is absolute path of the file in tmp folder
    #           echo file.filename
    #           echo file.contentType
    #
    #  - for more information you can also check documentation form the source:
    #       zfCore/zf/ctxReq.nim
    #       zfCore/zf/formData.nim
    #
    # capture the <id> from the path
    echo ctx.params["id"]
    await ctx.resp(Http200, "Hello World post request"))

zf.r.patch("/home/<id>", proc (ctx: CtxReq): Future[void] {.async.} =
    # capture the <id> from the path
    echo ctx.params["id"]
    await ctx.resp(Http200, "Hello World patch request"))

zf.r.delete("/home/<id>", proc (ctx: CtxReq): Future[void] {.async.} =
    # capture the <id> from the path
    echo ctx.params["id"]
    await ctx.resp(Http200, "Hello World delete request"))

zf.r.put("/home/<id>", proc (ctx: CtxReq): Future[void] {.async.} =
    # capture the <id> from the path
    echo ctx.params["id"]
    await ctx.resp(Http200, "Hello World put request"))

zf.r.head("/home/<id>", proc (ctx: CtxReq): Future[void] {.async.} =
    # capture the <id> from the path
    echo ctx.params["id"]
    await ctx.resp(Http200, "Hello World head request"))

# serve the zendflow
zf.serve()
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
    validation.valids -> contain valids field on validation (Table[string, FieldData])
    validation.notValids -> contain notValids field on validation (Table[string, FieldDat])
```

Fluent Validation containts this procedures for validation each FieldData:
1. must(errMsg: string = "your err msg")
will return errMsg if value empty
2. num(errMsg: string = "your err msg")
will return errMsg if value not a number
3. rangeNum(min: float64, max: float64, errMsg: string = "your errMsg")
will return errMsg if the number not in the range (min - max)
4. minNum(min: float64, errMsg: string = "your errMsg")
will return errMsg if the value less than min
5. maxNum(max: float64, errMsg: string = "your errMsg")
will return errMsg if the value larger than max
6. minLen(min: int, errMsg: string = "your errMsg")
will return errMsg if value length less than min
7. maxLen(max: int, errMsg: string = "your errMsg")
will return errMsg if value length more than max
8. rangeLen(min: int, max: int, errMsg: "your errMsg")
will return errMsg if value length not in range (min - max)
9. reMatch(regex: string, errMsg: string = "your errMsg")
eill return errMsg if the value not match with regex match pattern

## Core structure

- zfCore

This folder contain zfcore engine. The zfcore folder contains .nim file of zendflow building block also contain folder unpure, the unpure folder will contains unpure lib (thirdparty library)

zfcore contains:
1. ctxReq.nim
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
        responseHeader -> headers will send on response to user
]#
type
    CtxReq* = ref object
        client*: AsyncSocket
        reqMethod*: HttpMethod
        headers*: HttpHeaders
        protocol*: tuple[orig: string, major, minor: int]
        url*: Uri3
        hostname*: string
        body*: string
        params*: Table[string, string]
        reParams*: Table[string, seq[string]]
        formData*: FormData
        json*: JsonNode
        settings*: Settings
        responseHeaders*: HttpHeaders
```
2. formData.nim

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

8. viewRender.nim

This is experimental and should not be used

9. zendflow.nim

The is the starting building block

Thats it, feel free to modify and pull request if you have any idea, also this is the public domain we can share or you can cantact me on my email [amru.rosyada@amil.com](amru.rosyada@amil.com) to discuss further.

This is production ready :-), feel free to send me a bug to solve.

Need todo:
- ssl support (this not mandatory, we can done to run zendflow under nginx)
- orm integration
- websocket
- rpc

