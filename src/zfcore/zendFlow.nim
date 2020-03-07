#[
    ZendFlow web framework for nim language
    This framework if free to use and to modify
    License: BSD
    Author: Amru Rosyada
    Email: amru.rosyada@gmail.com
    Git: https://github.com/zendbit
]#
import
    asyncdispatch,
    asynchttpserver,
    strformat,
    sugar,
    router,
    route,
    ctxReq,
    tables,
    formData,
    json,
    settings,
    strtabs,
    uri3,
    strutils,
    os,
    times,
    asyncnet,
    fluentValidation

#[
    ZendFlow object definition
    this contain:
        server: is instance of AsyncHttpServer fo high performance httpserver
        r: is for routing object, we will use this for routing definition and will use it alot
        settings: is setting for the server contain setup for port, bind address, staticDir etc.
]#
type
    ZendFlow* = ref object
        server: AsyncHttpServer
        r*: Router
        settings*: Settings
        isCleanTmpDirExecuted: bool

#[
    newZendFlow is for instantiate the zendflow framework contain parameter settings.
    default value will run on port 8080, bind address 0.0.0.0 and staticDir point to www folder
]#
proc newZendFlow*(settings: Settings = newSettings()): ZendFlow =
    return ZendFlow(server: newAsyncHttpServer(
        reuseAddr = settings.reuseAddr, reusePort = settings.reusePort,
        maxBody = settings.maxBody), r: newRouter(), settings: settings)

#[
    this proc is private and will to use if the route not found or not match with router definition
    the ctx:Request is standard request from asynchttpserver
]#
proc httpMethodNotFoundAsync(self: ZendFlow, ctx: Request): Future[void] {.async.} =
    await ctx.respond(Http500, &"Request method not implemented: {ctx.reqMethod}")

#[
    this proc is private for sending request context to router, the request will process and parsed
    to make decision wich route tobe executed, ctx:Request is standard request from asynchttpserver
]#
proc sendToRouter(self: ZendFlow, ctx: Request): Future[void] {.async gcsafe.} =
    await self.r.executeProc(ctx, self.settings)

#[
    clean Tmp folder may take resource
    todo: should be have better approach for this method
]#
proc cleanTmpDir(self: ZendFlow, settings: Settings) {.gcsafe.} =
    for file in walkFiles(settings.tmpDir & "*"):
        # get all files
        let timestamp = splitPath(file)[1].split('_')[0]
        let timeInterval = toUnix(getTime()) - parseBiggestInt(timestamp)
        if timeInterval div 3600 >= 1:
            discard tryRemoveFile(file)

#[
    this proc is private for main dispatch of request
]#
proc mainHandlerAsync(self: ZendFlow, ctx: Request): Future[void] {.async gcsafe.} =
    if ctx.reqMethod in [HttpGet, HttpPost, HttpPut, HttpPatch,
        HttpDelete, HttpHead, HttpTrace, HttpOptions, HttpConnect]:
        await sendToRouter(self, ctx)
        # Chek cleanup tmp dir
        if not self.isCleanTmpDirExecuted:
            self.isCleanTmpDirExecuted = not self.isCleanTmpDirExecuted
            self.cleanTmpDir(self.settings)
            self.isCleanTmpDirExecuted = not self.isCleanTmpDirExecuted
    else:
        await httpMethodNotFoundAsync(self, ctx)

#[
    this proc is for start the ZendFlow, this will serve forever :-)
]#
proc serve*(self: ZendFlow) =
    echo &"ZendFlow listening your request on {self.settings.address}:{self.settings.port}"
    echo "Enjoy and take a cup of coffe :-)"

    proc cb(ctx: Request): Future[void] {.async gcsafe.} =
        let context = deepCopy(ctx)
        await self.mainHandlerAsync(context)

    waitFor self.server.serve(Port(self.settings.port), cb, self.settings.address)

export
    ctxReq,
    router,
    route,
    asyncdispatch,
    asynchttpserver,
    tables,
    formData,
    json,
    strtabs,
    uri3,
    strutils,
    times,
    os,
    settings,
    AsyncSocket,
    asyncnet,
    fluentValidation
