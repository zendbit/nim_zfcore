#[
  zfcore web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#

from zfblast import HttpContext, newZFBlast, ZFBlast, serve

import router, route, httpcontext, formdata, settings,
  fluentvalidation, apimsg
export httpcontext, router, route, formdata, settings,
  fluentvalidation, apimsg

const ZF_SETTINGS_FILE* = "settings.json"

#[
  ZFCore object definition
  this contain:
    server: is instance of AsyncHttpServer fo high performance httpserver
    r: is for routing object, we will use this for routing definition and will use it alot
    settings: is setting for the server contain setup for port, bind address, staticDir etc.
]#
type
  ZFCore* = ref object
    # port to zfblast server
    # server: AsyncHttpServer
    server: ZFBlast
    r*: Router
    settings*: Settings
    isCleanupTmpDirExecuted: bool

# checkThread for check the cleanup thread
var cleanUpThread {.threadvar.}: Thread[ZFCore]

#[
  newZFCore is for instantiate the zendflow framework contain parameter settings.
  default value will run on port 8080, bind address 0.0.0.0 and staticDir point to www folder
]#
proc newZFCore*(settings: Settings): ZFCore {.gcsafe.} =
  return ZFCore(
    server: newZFBlast(
      address = settings.address,
      port = Port(settings.port),
      reuseAddress = settings.reuseAddress,
      reusePort = settings.reusePort,
      maxBodyLength = settings.maxBodyLength,
      keepAliveMax = settings.keepAliveMax,
      keepAliveTimeout = settings.keepAliveTimeout,
      trace = settings.trace,
      sslSettings = settings.sslSettings),
    r: newRouter(),
    settings: settings)

proc zfJsonSettings*() : JsonNode =
  try:
    let sOp = open(ZF_SETTINGS_FILE)
    let settingsJson = sOp.readAll()
    sOp.close()
    result = parseJson(settingsJson)

  except:
    result = %*{}


# read setting from file
proc newZFCore*(): ZFCore {.gcsafe.} =
  let settingsJson = zfJsonSettings()
  if settingsJson.len != 0:
    let settings = newSettings()
    settings.sslSettings = SslSettings()
    var appRootDir = settingsJson{"appRootDir"}.getStr
    if appRootDir != "":
      settings.appRootDir = appRootDir
    else:
      settings.appRootDir = getAppDir()
    #if not settingsJson{"keepAliveMax"}.isNil:
    if settingsJson.hasKey("keepAliveMax"):
      settings.keepAliveMax = settingsJson{"keepAliveMax"}.getInt
    if settingsJson.hasKey("keepAliveTimeout"):
      settings.keepAliveTimeout = settingsJson{"keepAliveTimeout"}.getInt
    if settingsJson.hasKey("maxBodyLength"):
      settings.maxBodyLength = settingsJson{"maxBodyLength"}.getInt
    if settingsJson.hasKey("readBodyBuffer"):
      settings.readBodyBuffer = settingsJson{"readBodyBuffer"}.getInt
    if settingsJson.hasKey("responseRangeBuffer"):
      settings.responseRangeBuffer = settingsJson{"responseRangeBuffer"}.getInt
    if settingsJson.hasKey("maxResponseBodyLength"):
      settings.maxResponseBodyLength = settingsJson{"maxResponseBodyLength"}.getBiggestInt
    if settingsjson.hasKey("trace"):
      settings.trace = settingsjson{"trace"}.getBool
    if settingsJson.hasKey("http"):
      let httpSettings = settingsJson{"http"}
      if httpSettings.hasKey("port"):
        settings.port = httpSettings{"port"}.getInt
      if httpSettings.hasKey("address"):
        settings.address = httpSettings{"address"}.getStr
      if httpSettings.hasKey("reuseAddress"):
        settings.reuseAddress = httpSettings{"reuseAddress"}.getBool
      if httpSettings.hasKey("reusePort"):
        settings.reusePort = httpSettings{"reusePort"}.getBool
      if httpSettings.hasKey("secure"):
        let httpsSettings = httpSettings{"secure"}
        if httpsSettings.hasKey("port"):
          settings.sslSettings.port = httpsSettings{"port"}.getInt.Port
        if httpsSettings.hasKey("cert"):
          settings.sslSettings.certFile = httpsSettings{"cert"}.getStr
        if httpsSettings.hasKey("key"):
          settings.sslSettings.keyFile = httpsSettings{"key"}.getStr
        if httpSettings.hasKey("verify"):
          settings.sslSettings.verify = httpSettings{"verify"}.getBool


    return ZFCore(
      server: newZFBlast(
        address = settings.address,
        port = Port(settings.port),
        reuseAddress = settings.reuseAddress,
        reusePort = settings.reusePort,
        maxBodyLength = settings.maxBodyLength,
        keepAliveMax = settings.keepAliveMax,
        keepAliveTimeout = settings.keepAliveTimeout,
        trace = settings.trace,
        sslSettings = settings.sslSettings,
        readBodyBuffer = settings.readBodyBuffer),
      r: newRouter(),
      settings: settings)

  else:
    echo ""
    echo "Failed to load settings.json, using default settings."
    echo ""
    let settings = newSettings()
    settings.appRootDir = getAppDir()
    return ZFCore(
      server: newZFBlast(
        address = "0.0.0.0",
        port = Port(8080),
        trace = false,
        reuseAddress = true,
        reusePort = false,
        sslSettings = nil,
        maxBodyLength = 268435456,
        readBodyBuffer = 1024,
        keepAliveMax = 20,
        keepAliveTimeout = 10),
      r: newRouter(),
      settings: settings)

#[
  this proc is private and will to use if the route not found or not match with router definition
  the ctx:HttpContext is standard HttpContext from zfblast
]#
proc httpMethodNotFoundAsync(
  self: ZFCore,
  ctx: zfblast.HttpContext): Future[void] {.gcsafe async.} =

  ctx.response.httpCode = Http500
  ctx.response.body =
    &"Request method not implemented: {ctx.request.httpMethod}"

  await ctx.send(ctx)

#[
  this proc is private for sending request context to router, the request will process and parsed
  to make decision wich route tobe executed, ctx:HttpContext is standard HttpContext from zfblast
]#
proc sendToRouter(
  self: ZFCore,
  ctx: zfblast.HttpContext): Future[void] {.gcsafe async.} =

  try:
    await self.r.executeProc(ctx, self.settings)
  except Exception as ex:
    if self.settings.trace:
      asyncCheck trace proc (): void =
        echo ""
        echo "#== start"
        echo "#== zfcore trace"
        echo ex.msg
        echo "#== end"
        echo ""

proc `isCleanupTmpDir=`*(self: ZFCore, val: bool) =
  self.isCleanupTmpDirExecuted = val

proc `isCleanupTmpDir`*(self: ZFCore): bool =
  return self.isCleanupTmpDirExecuted

#[
  clean Tmp folder may take resource
  todo: should be have better approach for this method
]#
proc cleanTmpDir(zf: ZFCore) {.thread.} =
  #
  # cleanup process will spawn new thread if not exist
  # to check folder to cleanup
  #
  for dir in zf.settings.tmpCleanupDir:
    var toCleanup = zf.settings.tmpDir.joinPath(dir.dirName, "*")
    if dir.dirName == zf.settings.tmpDir:
      toCleanup = zf.settings.tmpDir
    for file in toCleanup.walkFiles:
      # get all files
      let timeInterval = getTime().toUnix - file.getLastAccessTime().toUnix
      # if interval set to 0, don't cleanup the file
      if timeInterval > dir.interval and dir.interval > 0:
        discard file.tryRemoveFile
        
  zf.isCleanupTmpDir = false

#[
  this proc is private for main dispatch of request
]#
proc mainHandlerAsync(
  self: ZFCore,
  ctx: zfblast.HttpContext): Future[void] {.gcsafe async.} =

  try:
    if ctx.request.httpmethod in [HttpGet, HttpPost, HttpPut, HttpPatch,
      HttpDelete, HttpHead, HttpTrace, HttpOptions, HttpConnect]:
      # set default headers content type
      ctx.response.headers["Content-Type"] = "text/plain; utf-8"

      await self.sendToRouter(ctx)

      # Chek cleanup tmp dir
      if not self.isCleanupTmpDir:
        self.isCleanupTmpDir = true
        createThread(cleanupThread, cleanTmpDir, self)

    else:
      await httpMethodNotFoundAsync(self, ctx)

  except Exception as ex:
    if self.settings.trace:
      asyncCheck trace proc (): void =
        echo ""
        echo "#== start"
        echo "#== zfcore trace"
        echo "Failed handle client request."
        echo ex.msg
        echo "#== end"
        echo ""

#[
  this proc is for start the ZendFlow, this will serve forever :-)
]#
proc serve*(self: ZFCore) {.gcsafe.} =
  echo "Enjoy and take a cup of coffe :-)"

  waitFor self.server.serve proc (ctx: zfblast.HttpContext): Future[void] {.gcsafe async.} =
    asyncCheck self.mainHandlerAsync(ctx)

# zfcore instance
# thread safe variable
var zfcoreInstanceVar* {.threadvar global.}: ZFCore

template zfcoreInstance*: ZFCore =
  if zfcoreInstanceVar.isNil:
    zfcoreInstanceVar = newZFCore()
  zfcoreInstanceVar

if not zfcoreInstance.settings.tmpDir.existsDir:
  zfcoreInstance.settings.tmpDir.createDir

include zfmacros
