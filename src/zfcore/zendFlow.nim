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
    strformat,
    sugar,
    router,
    route,
    httpCtx,
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
    fluentValidation,
    net,
    zfblast

#[
    ZendFlow object definition
    this contain:
        server: is instance of AsyncHttpServer fo high performance httpserver
        r: is for routing object, we will use this for routing definition and will use it alot
        settings: is setting for the server contain setup for port, bind address, staticDir etc.
]#
type
    ZendFlow* = ref object
        # port to zfblast server
        # server: AsyncHttpServer
        server: ZFBlast
        r*: Router
        settings*: Settings
        isCleanTmpDirExecuted: bool

#[
    newZendFlow is for instantiate the zendflow framework contain parameter settings.
    default value will run on port 8080, bind address 0.0.0.0 and staticDir point to www folder
]#
proc newZendFlow*(settings: Settings = newSettings()): ZendFlow =
    return ZendFlow(
        server: newZFBlast(
            address = settings.address,
            port = Port(settings.port),
            reuseAddress = settings.reuseAddress,
            reusePort = settings.reusePort,
            maxBodyLength = settings.maxBodyLength,
            keepAliveMax = settings.keepAliveMax,
            keepAliveTimeout = settings.keepAliveTimeout,
            debug = settings.debug,
            sslSettings = settings.sslSettings),
        r: newRouter(),
        settings: settings)

#[
    this proc is private and will to use if the route not found or not match with router definition
    the ctx:HttpContext is standard HttpContext from zfblast
]#
proc httpMethodNotFoundAsync(
    self: ZendFlow,
    ctx: HttpContext): Future[void] {.async.} =

    ctx.response.httpCode = Http500
    ctx.response.body =
        &"Request method not implemented: {ctx.request.httpMethod}"

    await ctx.send(ctx)

#[
    this proc is private for sending request context to router, the request will process and parsed
    to make decision wich route tobe executed, ctx:HttpContext is standard HttpContext from zfblast
]#
proc sendToRouter(
    self: ZendFlow,
    ctx: HttpContext): Future[void] {.async.} =

    await self.r.executeProc(ctx, self.settings)

#[
    clean Tmp folder may take resource
    todo: should be have better approach for this method
]#
proc cleanTmpDir(
    self: ZendFlow,
    settings: Settings) =

    for file in walkFiles(settings.tmpDir & "*"):
        # get all files
        let timestamp = splitPath(file)[1].split('_')[0]
        let timeInterval = toUnix(getTime()) - parseBiggestInt(timestamp)
        if timeInterval div 3600 >= 1:
            discard tryRemoveFile(file)

#[
    this proc is private for main dispatch of request
]#
proc mainHandlerAsync(
    self: ZendFlow,
    ctx: HttpContext): Future[void] {.async.} =

    if ctx.request.httpmethod in [HttpGet, HttpPost, HttpPut, HttpPatch,
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

    echo "Enjoy and take a cup of coffe :-)"

    waitFor self.server.serve(proc (ctx: HttpContext): Future[void] {.async.} =
        asyncCheck self.mainHandlerAsync(ctx))

export
    httpCtx,
    router,
    route,
    asyncdispatch,
    tables,
    formData,
    json,
    strtabs,
    uri3,
    strutils,
    times,
    os,
    settings,
    asyncnet,
    fluentValidation,
    zfblast,
    SslCVerifyMode
