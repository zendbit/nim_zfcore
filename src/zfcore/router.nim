#[
    ZendFlow web framework for nim language
    This framework if free to use and to modify
    License: BSD
    Author: Amru Rosyada
    Email: amru.rosyada@gmail.com
    Git: https://github.com/zendbit
]#
import
    re,
    httpCtx,
    strutils,
    strformat,
    asyncdispatch,
    tables,
    uri3,
    formData,
    json,
    middleware,
    route,
    os,
    settings,
    mime,
    httpcore,
    zfblast,
    osproc

#[
    Definition of the Router inherit from the Middleware
    the middleware is used for injecting process before route process and after route process
    with the middleware we can pass and evaluate entire request from the beforeRoute and afterRoute
    routes:seq[Route] -> is list of routes all route will registered to this list and the router will find the potential match
    staticRoutes for handle static file directory resource
]#
type
    Router* = ref object of Middleware
        routes: seq[Route]
        staticRoute: Route

#[
    Create new Router object, with default routes as zero list
]#
proc newRouter*(): Router {.gcsafe.} =

    return Router(routes: @[])

#[
    This proc is private and will process and matching the request with the list of the routes
    parameter is containt path segments of the registered route and path segment from the request
    this method will compare both to find the potential match.
    this will return tuple[success: bool, params: Table[string, string], reParams: Table[string, seq[string]]]
    success -> will be valued true, if the request match with one of route list
    params -> will be valued with list of parameter from the query string and path segment
    reParams -> will be valued with regex match if the regex match with the givend definition of the route segment
]#
proc matchesUri(
    self: Router,
    pathSeg: seq[string],
    uriSeg: seq[string]):
    tuple[
        success: bool,
        params: Table[string, string],
        reParams: Table[string, seq[string]]] =

    var success = true
    var reParams = initTable[string,seq[string]]()
    var params = initTable[string,string]()

    if pathSeg.len != uriSeg.len:
        success = false
    else:
        for i in 0..high(pathSeg):
            # check if matches with <tag-param>, ex: /home/<id>/index.html
            var paramTag: array[1, string]

            let currentPathSeg = decodeUri(pathSeg[i])
            let currentUriSeg = decodeUri(uriSeg[i])

            if match(currentPathSeg, re"<([\w\W]+)>$", paramTag):

                # parse uri eith regex without length value to get ex: /home/<ids:re[\\w]>
                var reParamsTag: array[3, string]

                # parse uri eith regex with length value to get ex: /home/<ids:re[(\\w+)_([0-9]+)]:len[2]>
                if match(
                    paramTag[0],
                    re"(\w+):re\[([\w\W]*)\]:len\[([0-9]+)\]$",
                    reParamsTag):
                    var reParamsSegmentTag: seq[string]
                    for i in 0..(parseInt(reParamsTag[2]) - 1):
                        reParamsSegmentTag.add("")

                    if match(currentUriSeg, re reParamsTag[1], reParamsSegmentTag):
                        reParams.add(reParamsTag[0], @ reParamsSegmentTag)

                    else:
                        success = false

                else:
                    params.add(paramTag[0], currentUriSeg)

            elif currentPathSeg != currentUriSeg:
                success = false

            # break and continue if current route not match
            if not success: break

    return (success: success, params: params, reParams: reParams)

#[
    Will return list of registered routes
]#
proc getRoutes*(self: Router): seq[Route] =

    return self.routes

#[
    This proc is private for parsing the path segment
]#
proc parseSegmentsFromPath(
    self: Router,
    path: string): seq[string] =

    return parseUri3(path).getPathSegments()

#[
    This proc is private and will parse the uri to table form
    ex: ?ok=true&hello=world will convert to {ok:true, hello:world}
]#
proc parseUriToTable(
    self: Router,
    uri: string): Table[string, string] =

    var query = initTable[string, string]()
    var uriToParse = uri
    if uri.find("?") == -1: uriToParse = &"?{uriToParse}"
    for q in parseUri3(uriToParse).getAllQueries():
        if (q.len == 2):
            query.add(q[0], decodeUri(q[1]))

    if query.len > 0:
        return query

#[
    This proc is private for mapt the content type
    HttpPost, HttpPut, HttpPatch will auto parse and extract the request, including the uploaded files
    uploaded files will save to tmp folder
]#
proc mapContentype(
    self: Router,
    ctx: HttpCtx) =

    let contentType = ctx.request.headers.getOrDefault("Content-Type")
    if ctx.request.httpMethod in [HttpPost, HttpPut, HttpPatch]:
        if contentType.find("multipart/form-data") != -1:
            ctx.formData = newFormData().parse(
                ctx.request.body,
                ctx.settings)

        if contentType.find("application/x-www-form-urlencoded") != -1:
            ctx.params = self.parseUriToTable(ctx.request.body)

        if contentType.find("application/json") != -1:
            ctx.json = parseJson(ctx.request.body)

#[
    Handle static resource, this should be only allow get method
    all static resource should be access using prefix /s/
    example static di is in this form:
        www/styles/*.css
        www/js/*.js
        www/img/*.jpg
        etc
    we can call from the url using this form:
        /s/style/*.css
        /s/js/*.js
        /s/img/*.jpg
        etc
]#
proc handleStaticRoute(
    self: Router,
    ctx: HttpCtx):
    Future[tuple[
            found: bool,
            filePath: string,
            contentType: string]] {.async.} =

    if not isNil(self.staticRoute):
        # get route from the path
        var routePath = decodeUri(self.staticRoute.path)
        # get static path from the request url
        var staticPath = decodeUri(ctx.request.url.getPath())
        if ctx.request.httpMethod == HttpGet:
            # only if static path from the request url start with the route path
            if staticPath.startsWith(routePath) and
                routePath != staticPath:
                # static dir will search under staticDir in settings section
                let staticSearchDir = ctx.settings.staticDir & staticPath
                if fileExists(staticSearchDir):
                    # define contentType of the file
                    # default is "application/octet-stream"
                    var contentType = "application/octet-stream"
                    # define extension of the requested file
                    var ext: array[1, string]
                    if match(staticPath, re"[\w\W]+\.([\w]+)$", ext):
                        # if extension is defined then try to search the contentType
                        let mimeType = newMimeType().getMimeType(
                            ("." & ext[0]).toLower())
                        # override the contentType if we found it
                        if mimeType != "":
                            contentType = mimeType

                    return (
                        found: true,
                        filePath: staticSearchDir,
                        contentType: contentType)

#[
    Handle dynamic route and middleware
]#
proc handleDynamicRoute(
    self: Router,
    ctx: HttpCtx): Future[void] {.async.} =
    # execute middleware before routing
    if await self.execBeforeRoute(ctx): return
    # call static route before the dynamic route
    let (staticFound, staticFilePath, staticContentType) =
        await self.handleStaticRoute(ctx)
    # map content type
    self.mapContentype(ctx)

    # route to potensial uri
    # also extract the uri parameter
    let ctxSegments = self.parseSegmentsFromPath(ctx.request.url.getPath())
    #var exec: proc (ctx: HttpCtx): Future[void] {.gcsafe.}
    var route: Route
    for r in self.routes:
        let matchesUri = self.matchesUri(r.segments, ctxSegments)
        if r.httpMethod == ctx.request.httpMethod and
            matchesUri.success:
            route = r
            for k, v in matchesUri.params:
                ctx.params.add(k, v)

            for qStr in ctx.request.url.getAllQueries():
                if qStr.len == 2:
                    ctx.params.add(qStr[0], decodeUri(qStr[1]))

            ctx.reParams = matchesUri.reParams

            break

    if route != nil:
        # execute middleware after routing before respond
        if await self.execAfterRoute(ctx, route): return

        # execute route callback
        await route.thenDo(ctx)

    elif staticFound:
        let file = open(staticFilePath, fmRead)
        let body = file.readAll()
        file.close()
        ctx.response.headers["Content-Type"] = staticContentType & "; charset=utf-8"
        ctx.resp(Http200, body)

    else:
        # default response if route does not match
        ctx.resp(Http404, &"Resource not found {ctx.request.url.getPath()}")

#[
    This proc will execute the registered callback procedure in route list.
    asynchttpserver Request will convert to HttpCtx.
    beforeRoute and afterRoute middleware will evaluated here
]#
proc executeProc*(
    self: Router,
    ctx: HttpContext,
    settings: Settings): Future[void] {.async.} =

    var httpCtx = newHttpCtx(ctx)
    httpCtx.settings = settings

    await self.handleDynamicRoute(httpCtx)

proc static*(
    self: Router,
    path: string) =

    self.staticRoute = Route(
        path: path,
        httpMethod: HttpGet,
        thenDo: nil,
        segments: self.parseSegmentsFromPath(path))

#[
    let zf = newZendFlow()

    #### Register the post route to the framework
    #### example with regex to extract the segment
    #### this regex will match with /home/123_12345/test
    #### the regex will capture ids -> @["123", "12345"]
    #### the <body> parameter will capture body -> test
    zf.r.get("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
        ctx: HttpCtx): Future[void] {.async.} =
        echo "Welcome home"
        echo $ctx.reParams["ids"]
        echo $ctx.params["body"]
        await ctx.resp(Http200, "Hello World"))

    #### without regex
    #### will accept from /home
    zf.r.get("/home", proc (
        ctx: HttpCtx): Future[void] {.async.} =

        #### your code here

        await ctx.resp(Http200, "Hello World"))

    #### start the server
    zf.serve()
]#
proc get*(
    self: Router,
    path: string,
    thenDo: proc(ctx: HttpCtx): Future[void]) =

    self.routes.add(
        Route(
            path: path,
            httpMethod: HttpGet,
            thenDo: thenDo,
            segments: self.parseSegmentsFromPath(path)))

#[
    let zf = newZendFlow()

    #### Register the post route to the framework
    #### example with regex to extract the segment
    #### this regex will match with /home/123_12345/test
    #### the regex will capture ids -> @["123", "12345"]
    #### the <body> parameter will capture body -> test
    zf.r.post("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
        ctx: HttpCtx): Future[void] {.async.} =
        echo "Welcome home"
        echo $ctx.reParams["ids"]
        echo $ctx.params["body"]
        await ctx.resp(Http200, "Hello World"))

    #### without regex
    zf.r.post("/home", proc (
        ctx: HttpCtx): Future[void] {.async.} =

        #### your code here

        await ctx.resp(Http200, "Hello World"))

    #### start the server
    zf.serve()
]#
proc post*(
    self: Router,
    path: string,
    thenDo: proc(ctx: HttpCtx): Future[void]) =

    self.routes.add(
        Route(
            path: path,
            httpMethod: HttpPost,
            thenDo: thenDo,
            segments: self.parseSegmentsFromPath(path)))

#[
    let zf = newZendFlow()

    #### Register the post route to the framework
    #### example with regex to extract the segment
    #### this regex will match with /home/123_12345/test
    #### the regex will capture ids -> @["123", "12345"]
    #### the <body> parameter will capture body -> test
    zf.r.put("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
        ctx: HttpCtx): Future[void] {.async.} =
        echo "Welcome home"
        echo $ctx.reParams["ids"]
        echo $ctx.params["body"]
        await ctx.resp(Http200, "Hello World"))

    #### without regex
    zf.r.put("/home", proc (
        ctx: HttpCtx): Future[void] {.async.} =

        #### your code here

        await ctx.resp(Http200, "Hello World"))

    #### start the server
    zf.serve()
]#
proc put*(
    self: Router,
    path: string,
    thenDo: proc(ctx: HttpCtx): Future[void]) =

    self.routes.add(
        Route(
            path: path,
            httpMethod: HttpPut,
            thenDo: thenDo,
            segments: self.parseSegmentsFromPath(path)))

#[
    let zf = newZendFlow()

    #### Register the post route to the framework
    #### example with regex to extract the segment
    #### this regex will match with /home/123_12345/test
    #### the regex will capture ids -> @["123", "12345"]
    #### the <body> parameter will capture body -> test
    zf.r.delete("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
        ctx: HttpCtx): Future[void] {.async.} =
        echo "Welcome home"
        echo $ctx.reParams["ids"]
        echo $ctx.params["body"]
        await ctx.resp(Http200, "Hello World"))

    #### without regex
    zf.r.delete("/home", proc (
        ctx: HttpCtx): Future[void] {.async.} =

        #### your code here

        await ctx.resp(Http200, "Hello World"))

    #### start the server
    zf.serve()
]#
proc delete*(
    self: Router,
    path: string,
    thenDo: proc(ctx: HttpCtx): Future[void]) =

    self.routes.add(
        Route(
            path: path,
            httpMethod: HttpDelete,
            thenDo: thenDo,
            segments: self.parseSegmentsFromPath(path)))

#[
    let zf = newZendFlow()

    #### Register the post route to the framework
    #### example with regex to extract the segment
    #### this regex will match with /home/123_12345/test
    #### the regex will capture ids -> @["123", "12345"]
    #### the <body> parameter will capture body -> test
    zf.r.patch("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
        ctx: HttpCtx): Future[void] {.async.} =
        echo "Welcome home"
        echo $ctx.reParams["ids"]
        echo $ctx.params["body"]
        await ctx.resp(Http200, "Hello World"))

    #### without regex
    zf.r.patch("/home", proc (
        ctx: HttpCtx): Future[void] {.async.} =

        #### your code here

        await ctx.resp(Http200, "Hello World"))

    #### start the server
    zf.serve()
]#
proc patch*(
    self: Router,
    path: string,
    thenDo: proc(ctx: HttpCtx): Future[void]) =

    self.routes.add(
        Route(
            path: path,
            httpMethod: HttpPatch,
            thenDo: thenDo,
            segments: self.parseSegmentsFromPath(path)))

#[
    let zf = newZendFlow()

    #### Register the post route to the framework
    #### example with regex to extract the segment
    #### this regex will match with /home/123_12345/test
    #### the regex will capture ids -> @["123", "12345"]
    #### the <body> parameter will capture body -> test
    zf.r.head("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
        ctx: HttpCtx): Future[void] {.async.} =
        echo "Welcome home"
        echo $ctx.reParams["ids"]
        echo $ctx.params["body"]
        await ctx.resp(Http200, "Hello World"))

    #### without regex
    zf.r.head("/home", proc (
        ctx: HttpCtx): Future[void] {.async.} =

        #### your code here

        await ctx.resp(Http200, "Hello World"))

    #### start the server
    zf.serve()
]#
proc head*(
    self: Router,
    path: string,
    thenDo: proc(ctx: HttpCtx): Future[void]) =

    self.routes.add(
        Route(
            path: path,
            httpMethod: HttpHead,
            thenDo: thenDo,
            segments: self.parseSegmentsFromPath(path)))

proc options*(
    self: Router,
    path: string,
    thenDo: proc(ctx: HttpCtx): Future[void]) =

    self.routes.add(
        Route(
            path: path,
            httpMethod: HttpOptions,
            thenDo: thenDo,
            segments: self.parseSegmentsFromPath(path)))

proc trace*(
    self: Router,
    path: string,
    thenDo: proc(ctx: HttpCtx): Future[void]) =

    self.routes.add(
        Route(
            path: path,
            httpMethod: HttpTrace,
            thenDo: thenDo,
            segments: self.parseSegmentsFromPath(path)))

proc connect*(
    self: Router,
    path: string,
    thenDo: proc(ctx: HttpCtx): Future[void]) =

    self.routes.add(
        Route(
            path: path,
            httpMethod: HttpConnect,
            thenDo: thenDo,
            segments: self.parseSegmentsFromPath(path)))

export
    beforeRoute,
    afterRoute

