#[
  zfcore web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#

import
  asyncdispatch,
  strformat,
  tables,
  json,
  strtabs,
  os,
  times,
  asyncnet,
  net,
  strutils,
  httpcore

import
  uri3

import
  router,
  route,
  httpcontext,
  formdata,
  settings,
  fluentvalidation,
  zfmacros,
  apimsg
  
from
  zfblast
    import
      HttpContext,
      newZFBlast,
      getHttpHeaderValues,
      ZFBlast,
      trace,
      serve

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
    isCleanTmpDirExecuted: bool

#[
  newZFCore is for instantiate the zendflow framework contain parameter settings.
  default value will run on port 8080, bind address 0.0.0.0 and staticDir point to www folder
]#
proc newZFCore*(settings: Settings): ZFCore =
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
    return parseJson(settingsJson)

  except:
    return JsonNode()


# read setting from file
proc newZFCore*(): ZFCore =
  let settingsJson = zfJsonSettings()
  if settingsJson.len != 0:
    let settings = newSettings()
    settings.sslSettings = SslSettings()
    var appRootDir = settingsJson{"appRootDir"}.getStr
    if appRootDir != "":
      settings.appRootDir = appRootDir
    else:
      settings.appRootDir = getAppDir()
    if not settingsJson{"keepAliveMax"}.isNil:
      settings.keepAliveMax = settingsJson{"keepAliveMax"}.getInt
    if not settingsJson{"keepAliveTimeout"}.isNil:
      settings.keepAliveTimeout = settingsJson{"keepAliveTimeout"}.getInt
    if not settingsJson{"maxBodyLength"}.isNil:
      settings.maxBodyLength = settingsJson{"maxBodyLength"}.getInt
    if not settingsJson{"readBodyBuffer"}.isNil:
      settings.readBodyBuffer = settingsJson{"readBodyBuffer"}.getInt
    if not settingsJson{"responseRangeBuffer"}.isNil:
      settings.responseRangeBuffer = settingsJson{"responseRangeBuffer"}.getInt
    if not settingsJson{"maxResponseBodyLength"}.isNil:
      settings.maxResponseBodyLength = settingsJson{"maxResponseBodyLength"}.getBiggestInt
    if not settingsjson{"trace"}.isNil:
      settings.trace = settingsjson{"trace"}.getBool
    let httpSettings = settingsJson{"http"}
    if not httpSettings.isNil:
      if not httpSettings{"port"}.isNil:
        settings.port = httpSettings{"port"}.getInt
      if not httpSettings{"address"}.isNil:
        settings.address = httpSettings{"address"}.getStr
      if not httpSettings{"reuseAddress"}.isNil:
        settings.reuseAddress = httpSettings{"reuseAddress"}.getBool
      if not httpSettings{"reusePort"}.isNil:
        settings.reusePort = httpSettings{"reusePort"}.getBool
      let httpsSettings = httpSettings{"secure"}
      if not httpsSettings.isNil:
        if not httpsSettings{"port"}.isNil:
          settings.sslSettings.port = httpsSettings{"port"}.getInt.Port
        if not httpsSettings{"cert"}.isNil:
          settings.sslSettings.certFile = httpsSettings{"cert"}.getStr
        if not httpsSettings{"key"}.isNil:
          settings.sslSettings.keyFile = httpsSettings{"key"}.getStr
        if not httpSettings{"verify"}.isNil:
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
  ctx: zfblast.HttpContext): Future[void] {.async.} =

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
  ctx: zfblast.HttpContext): Future[void] {.async.} =

  try:
    await self.r.executeProc(ctx, self.settings)
  except Exception as ex:
    if self.settings.trace:
      asyncCheck trace do () -> void:
        echo ""
        echo "#== start"
        echo "#== zfcore trace"
        echo ex.msg
        echo "#== end"
        echo ""

#[
  clean Tmp folder may take resource
  todo: should be have better approach for this method
]#
proc cleanTmpDir(
  self: ZFCore,
  settings: Settings) =

  for dir in settings.tmpCleanupDir:
    var toCleanup = settings.tmpDir.joinPath(dir.dirName, "*")
    if dir.dirName == settings.tmpDir:
      toCleanup = settings.tmpDir
    for file in toCleanup.walkFiles:
      # get all files
      let timeInterval = getTime().toUnix - file.getLastAccessTime().toUnix
      # if interval set to 0, don't cleanup the file
      if timeInterval > dir.interval and dir.interval > 0:
        discard file.tryRemoveFile

#[
  this proc is private for main dispatch of request
]#
proc mainHandlerAsync(
  self: ZFCore,
  ctx: zfblast.HttpContext): Future[void] {.async.} =

  try:
    if ctx.request.httpmethod in [HttpGet, HttpPost, HttpPut, HttpPatch,
      HttpDelete, HttpHead, HttpTrace, HttpOptions, HttpConnect]:
      # set default headers content type
      ctx.response.headers["Content-Type"] = "text/plain; utf-8"

      await self.sendToRouter(ctx)
      # Chek cleanup tmp dir
      if not self.isCleanTmpDirExecuted:
        self.isCleanTmpDirExecuted = not self.isCleanTmpDirExecuted
        self.cleanTmpDir(self.settings)
        self.isCleanTmpDirExecuted = not self.isCleanTmpDirExecuted

    else:
      await httpMethodNotFoundAsync(self, ctx)

  except Exception as ex:
    if self.settings.trace:
      asyncCheck trace do () -> void:
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
proc serve*(self: ZFCore) =

  echo "Enjoy and take a cup of coffe :-)"

  waitFor self.server.serve do (ctx: zfblast.HttpContext) -> Future[void] {.async.}:
    asyncCheck self.mainHandlerAsync(ctx)

# zfcore instance
let zfc* {.global.} = newZfCore()

if not zfc.settings.tmpDir.existsDir:
  zfc.settings.tmpDir.createDir

export
  asyncdispatch,
  tables,
  json,
  strtabs,
  strutils,
  times,
  os,
  asyncnet,
  httpcore,
  strformat

export
  uri3,
  getHttpHeaderValues

export
  httpcontext,
  router,
  route,
  formdata,
  settings,
  fluentvalidation,
  zfmacros,
  apimsg
