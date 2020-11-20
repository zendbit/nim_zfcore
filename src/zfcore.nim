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
  fluentvalidation, apimsg, threadpool, macros
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

#[
  newZFCore is for instantiate the zendflow framework contain parameter settings.
  default value will run on port 8080, bind address 0.0.0.0 and staticDir point to www folder
]#
proc newZFCore*(settings: Settings): ZFCore {.gcsafe.} =
  return ZFCore(
    server: newZFBlast(
      address = settings.address,
      port = settings.port,
      reuseAddress = settings.reuseAddress,
      reusePort = settings.reusePort,
      maxBodyLength = settings.maxBodyLength,
      keepAlive = settings.keepAlive,
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
    if settingsJson.hasKey("keepAlive"):
      settings.keepAlive = settingsJson{"keepAlive"}.getBool
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
        settings.port = httpSettings{"port"}.getInt.Port
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
        port = settings.port,
        reuseAddress = settings.reuseAddress,
        reusePort = settings.reusePort,
        maxBodyLength = settings.maxBodyLength,
        keepAlive = settings.keepAlive,
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
        keepAlive = false),
      r: newRouter(),
      settings: settings)

#[
  this proc is private and will to use if the route not found or not match with router definition
  the ctx:HttpContext is standard HttpContext from zfblast
]#
proc httpMethodNotFoundAsync(
  self: ZFCore,
  ctx: zfblast.HttpContext) {.gcsafe async.} =

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
  ctx: zfblast.HttpContext) {.gcsafe async.} =

  try:
    await self.r.executeProc(ctx, self.settings)
  except Exception as ex:
    if self.settings.trace:
      trace proc (): void =
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

proc cleanupThread(settings: Settings) =
  #
  # cleanup process will spawn new thread if not exist
  # to check folder to cleanup
  #
  while true:
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

    60000.sleep

#[
  this proc is private for main dispatch of request
]#
proc mainHandler(
  self: ZFCore,
  ctx: zfblast.HttpContext) {.gcsafe async.} =

  try:
    if ctx.request.httpmethod in [HttpGet, HttpPost, HttpPut, HttpPatch,
      HttpDelete, HttpHead, HttpTrace, HttpOptions, HttpConnect]:
      # set default headers content type
      ctx.response.headers["Content-Type"] = "text/plain; utf-8"

      await self.sendToRouter(ctx)

    else:
      await httpMethodNotFoundAsync(self, ctx)

  except Exception as ex:
    if self.settings.trace:
      trace proc (): void =
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
proc serve*(self: ZFCore) {.gcsafe async.} =
  echo "Enjoy and take a cup of coffe :-)"

  # start cleanup thread
  spawn cleanupThread(self.settings.deepCopy)

  self.server.serve proc (ctx: zfblast.HttpContext) {.gcsafe async.} =
    await self.mainHandler(ctx)

# zfcore instance
let zfcoreInstance* {.global.} = newZFCore()

if not zfcoreInstance.settings.tmpDir.existsDir:
  zfcoreInstance.settings.tmpDir.createDir

###
### macros for the zfcore
###
macro routes*(group, body: untyped = nil): untyped =
  var x: NimNode = body
  var routeGroup: string = ""
  
  if group.kind == nnkStmtList:
    x = group
  elif group.kind == nnkStrLit:
    routeGroup = $group

  let stmtList = newStmtList()
  for child in x.children:
    if child.kind == nnkCommentStmt:
      stmtList.add(child)
      continue

    let childKind = ($child[0]).strip
    case child.kind
    of nnkCall:
      var childStmtList: NimNode = child
      if child.len > 1:
        childStmtList = child[1]
      case childKind
      of "after":
        stmtList.add(
          nnkCall.newTree(
            nnkDotExpr.newTree(
              nnkDotExpr.newTree(
                newIdentNode("zfcoreInstance"),
                newIdentNode("r")
              ),
              newIdentNode("addAfterRoute")
            ),
            nnkLambda.newTree(
              newEmptyNode(),
              newEmptyNode(),
              newEmptyNode(),
              nnkFormalParams.newTree(
                nnkBracketExpr.newTree(
                  newIdentNode("Future"),
                  nnkDotExpr.newTree(
                    newIdentNode("system"),
                    newIdentNode("bool")
                  )
                ),
                nnkIdentDefs.newTree(
                  newIdentNode("ctx"),
                  newIdentNode("HttpContext"),
                  newEmptyNode()
                ),
                nnkIdentDefs.newTree(
                  newIdentNode("route"),
                  newIdentNode("Route"),
                  newEmptyNode()
                )
              ),
              nnkPragma.newTree(
                newIdentNode("gcsafe"),
                newIdentNode("async")
              ),
              newEmptyNode(),
              childStmtList
            )
          )
        )

      of "before":
        stmtList.add(
          nnkCall.newTree(
            nnkDotExpr.newTree(
              nnkDotExpr.newTree(
                newIdentNode("zfcoreInstance"),
                newIdentNode("r")
              ),
              newIdentNode("addBeforeRoute")
            ),
            nnkLambda.newTree(
              newEmptyNode(),
              newEmptyNode(),
              newEmptyNode(),
              nnkFormalParams.newTree(
                nnkBracketExpr.newTree(
                  newIdentNode("Future"),
                  nnkDotExpr.newTree(
                    newIdentNode("system"),
                    newIdentNode("bool")
                  )
                ),
                nnkIdentDefs.newTree(
                  newIdentNode("ctx"),
                  newIdentNode("HttpContext"),
                  newEmptyNode()
                )
              ),
              nnkPragma.newTree(
                newIdentNode("gcsafe"),
                newIdentNode("async")
              ),
              newEmptyNode(),
              childStmtList
            )
          )
        )

      else:
        stmtList.add(child)

    of nnkCommand:
      let route = routeGroup & ($child[1]).strip()
      case childKind
      of "get", "post", "head",
        "patch", "delete", "put",
        "options", "connect", "trace":

        let childStmtList = child[2]
        stmtList.add(
          nnkCall.newTree(
            nnkDotExpr.newTree(
              nnkDotExpr.newTree(
                newIdentNode("zfcoreInstance"),
                newIdentNode("r")
              ),
              newIdentNode(childKind)
            ),
            newLit(route),
            nnkLambda.newTree(
              newEmptyNode(),
              newEmptyNode(),
              newEmptyNode(),
              nnkFormalParams.newTree(
                newEmptyNode(),
                nnkIdentDefs.newTree(
                  newIdentNode("ctx"),
                  newIdentNode("HttpContext"),
                  newEmptyNode()
                )
              ),
              nnkPragma.newTree(
                newIdentNode("gcsafe"),
                newIdentNode("async")
              ),
              newEmptyNode(),
              childStmtList
            )
          )
        )

      of "staticDir":
        stmtList.add(
          nnkStmtList.newTree(
            nnkCall.newTree(
              nnkDotExpr.newTree(
                nnkDotExpr.newTree(
                  newIdentNode("zfcoreInstance"),
                  newIdentNode("r")
                ),
                newIdentNode("static")
              ),
              newLit(route)
            )
          )
        )

      else:
        stmtList.add(child)

    else:
      stmtList.add(child)

  #stmtList.add(
  #  nnkCall.newTree(
  #    nnkDotExpr.newTree(
  #      newIdentNode("zfcoreInstance"),
  #      newIdentNode("serve")
  #    )
  #  )
  #)

  return stmtList

macro emitServer*() =
  nnkCommand.newTree(
    newIdentNode("waitFor"),
    nnkCall.newTree(
        nnkDotExpr.newTree(
          newIdentNode("zfcoreInstance"),
          newIdentNode("serve")
        )
      )
  )

macro resp*(
  httpCode: HttpCode,
  body: untyped,
  headers: HttpHeaders = nil) =
  nnkCommand.newTree(
    newIdentNode("await"),
    nnkCall.newTree(
      nnkDotExpr.newTree(
        newIdentNode("ctx"),
        newIdentNode("resp")
      ),
      httpCode,
      body,
      headers
    )
  )

macro respHtml*(
  httpCode: HttpCode,
  body: string,
  headers: HttpHeaders = nil) =
  nnkCommand.newTree(
    newIdentNode("await"),
    nnkCall.newTree(
      nnkDotExpr.newTree(
        newIdentNode("ctx"),
        newIdentNode("respHtml")
      ),
      httpCode,
      body,
      headers
    )
  )

macro respRedirect*(redirectTo: string) =
  nnkCommand.newTree(
    newIdentNode("await"),
    nnkCall.newTree(
      nnkDotExpr.newTree(
        newIdentNode("ctx"),
        newIdentNode("respRedirect")
      ),
      redirectTo
    )
  )

macro setCookie*(
  cookies: StringTableRef, domain: untyped = "",
  path: untyped = "", expires: untyped = "",
  secure: untyped = false) =
  nnkCall.newTree(
    nnkDotExpr.newTree(
      newIdentNode("ctx"),
      newIdentNode("setCookie")
    ),
    cookies,
    domain,
    path,
    expires,
    secure
  )

macro getCookie*(): untyped =
  return nnkCall.newTree(
    nnkDotExpr.newTree(
      newIdentNode("ctx"),
      newIdentNode("getCookie")
    )
  )

macro clearCookie*(cookies: untyped) =
  nnkCall.newTree(
    nnkDotExpr.newTree(
      newIdentNode("ctx"),
      newIdentNode("clearCookie")
    ),
    cookies
  )

macro req*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("request")
  )

macro res*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("response")
  )

macro config*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("settings")
  )

macro client*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("client")
  )

macro ws*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("webSocket")
  )

macro params*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("params")
  )

macro reParams*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("reParams")
  )

macro formData*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("formData")
  )

macro json*: JsonNode =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("json")
  )

