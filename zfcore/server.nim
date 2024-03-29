##
##  zfcore web framework for nim language
##  This framework if free to use and to modify
##  License: BSD
##  Author: Amru Rosyada
##  Email: amru.rosyada@gmail.com
##  Git: https://github.com/zendbit/nim.zfcore
##

##  zfblast import
import zfblast/server as zfbserver
import zfblast/[
  server,
  websocket,
  constants]

import
  router,
  route,
  httpcontext,
  formdata,
  settings,
  fluentvalidation,
  respmsg

##  std import
import
  threadpool,
  macros,
  stdext/xsystem

export
  httpcontext,
  router,
  route,
  formdata,
  settings,
  fluentvalidation,
  respmsg,
  websocket,
  constants,
  isProductionMode

const ZF_SETTINGS_FILE* = "config".joinPath("settings.json")

#[
  ZFCore object definition
  this contain:
    server: is instance of AsyncHttpServer fo high performance httpserver
    r: is for routing object, we will use this for routing definition and will use it alot
    settings: is setting for the server contain setup for port, bind address, staticDir etc.
]#
type
  ZFCore* = ref object of RootObj
    ##
    ##  port to zfblast server
    ##  server: AsyncHttpServer
    ##
    server*: ZFBlast
    r*: Router
    settings*: Settings
    tasksPool*: Table[string, TasksPoolAction]

  TasksPoolAction* = ref object of RootObj
    action*: proc (param: JsonNode)
    param*: JsonNode

proc initSystemTasksPool(self: ZFCore) =
  ##
  ##  init system taskspool
  ##  this will execute every time taskspool checked
  ##
  self.tasksPool["zfcore"] = TasksPoolAction(
    action: proc (param: JsonNode) =
      let settings = param.to(Settings)
      for dir in settings.tmpCleanupDir:
        var toCleanup = settings.tmpDir.joinPath(dir.dirName, "*")
        if dir.dirName == settings.tmpDir:
          toCleanup = settings.tmpDir

        for file in toCleanup.walkFiles:
          # get all files
          let timeGap = getTime().toUnix - file.getLastAccessTime().toUnix

          # if interval set to 0, don't cleanup the file
          # default action cleanup if no action procedure on cleanup
          if timeGap > dir.expired and dir.expired > 0:
            discard file.tryRemoveFile
    ,
    param: %self.settings
  )

#[
  newZFCore is for instantiate the zendflow framework contain parameter settings.
  default value will run on port 8080, bind address 0.0.0.0 and staticDir point to www folder
]#
proc newZFCore*(settings: Settings): ZFCore {.gcsafe.} =
  ##
  ##  new zfcore object:
  ##
  ##  create zfcore object with given settings.
  ##
  result = ZFCore(
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
    settings: settings,
    tasksPool: initTable[string, TasksPoolAction]())

  result.initSystemTasksPool

proc zfJsonSettings*(): JsonNode =
  ##
  ##  json settings:
  ##
  ##  will try to read settings.json, if not exists will use default setting.
  ##
  {.gcsafe.}:
    try:
      let settingsFile = getAppDir().joinPath(ZF_SETTINGS_FILE)
      if settingsFile.fileExists:
        result = parseFile(settingsFile)

    except Exception as ex:
      echo ex.msg
      result = %*{}

proc configureSettings*(
  settings: Settings,
  settingsJson: JsonNode): Settings =
  ##
  ##  settng configuration this is will populate core section
  ##  on the settings.json file
  ##

  var mergeSettings: Settings = settings

  if not settingsJson.isNil:
    if mergeSettings.sslSettings.isNil:
      mergeSettings.sslSettings = SslSettings()

    var appRootDir = settingsJson{$@Settings.appRootDir}.getStr
    if appRootDir != "":
      mergeSettings.appRootDir = appRootDir
    else:
      mergeSettings.appRootDir = getAppDir()
    if settingsJson.hasKey($@Settings.keepAlive):
      mergeSettings.keepAlive = settingsJson{$@Settings.keepAlive}.getBool
    if settingsJson.hasKey($@Settings.maxBodyLength):
      mergeSettings.maxBodyLength = settingsJson{$@Settings.maxBodyLength}.getInt
    if settingsJson.hasKey($@Settings.readBodyBuffer):
      mergeSettings.readBodyBuffer = settingsJson{$@Settings.readBodyBuffer}.getInt
    if settingsJson.hasKey($@Settings.responseRangeBuffer):
      mergeSettings.responseRangeBuffer = settingsJson{$@Settings.responseRangeBuffer}.getInt
    if settingsJson.hasKey($@Settings.maxResponseBodyLength):
      mergeSettings.maxResponseBodyLength = settingsJson{$@Settings.maxResponseBodyLength}.getBiggestInt
    if settingsjson.hasKey($@Settings.trace):
      mergeSettings.trace = settingsjson{$@Settings.trace}.getBool
    if settingsjson.hasKey($@Settings.contentTypeToCompress):
      mergeSettings.contentTypeToCompress = settingsjson{$@Settings.contentTypeToCompress}.to(seq[string])
    if settingsJson.hasKey("http"):
      let httpSettings = settingsJson{"http"}
      if httpSettings.hasKey($@Settings.port):
        mergeSettings.port = httpSettings{$@Settings.port}.getInt.Port
      if httpSettings.hasKey($@Settings.address):
        mergeSettings.address = httpSettings{$@Settings.address}.getStr
      if httpSettings.hasKey($@Settings.reuseAddress):
        mergeSettings.reuseAddress = httpSettings{$@Settings.reuseAddress}.getBool
      if httpSettings.hasKey($@Settings.reusePort):
        mergeSettings.reusePort = httpSettings{$@Settings.reusePort}.getBool
      if httpSettings.hasKey("secure"):
        let httpsSettings = httpSettings{"secure"}
        if httpsSettings.hasKey($@SslSettings.port):
          mergeSettings.sslSettings.port = httpsSettings{$@SslSettings.port}.getInt.Port
        if httpsSettings.hasKey($@SslSettings.certFile):
          mergeSettings.sslSettings.certFile = httpsSettings{$@SslSettings.certFile}.getStr
        if httpsSettings.hasKey($@SslSettings.keyFile):
          mergeSettings.sslSettings.keyFile = httpsSettings{$@SslSettings.keyFile}.getStr
        if httpsSettings.hasKey($@SslSettings.verify):
          mergeSettings.sslSettings.verify = httpsSettings{$@SslSettings.verify}.getBool
        if httpsSettings.hasKey($@SslSettings.useEnv):
          mergeSettings.sslSettings.useEnv = httpsSettings{$@SslSettings.useEnv}.getBool
        if httpsSettings.hasKey($@SslSettings.caDir):
          mergeSettings.sslSettings.caDir = httpsSettings{$@SslSettings.caDir}.getStr
        if httpsSettings.hasKey($@SslSettings.caFile):
          mergeSettings.sslSettings.caFile = httpsSettings{$@SslSettings.caFile}.getStr

  var settingsToMerge: JsonNode

  when defined(release):
    settingsToMerge = settingsJson{"release"}

  else:
    settingsToMerge = settingsJson{"debug"}

  if not settingsToMerge.isNil:
    mergeSettings = mergeSettings.configureSettings(settingsToMerge)

  result = mergeSettings

proc applySettings*(
  zfcore:ZFCore,
  settings: Settings) =

  zfcore.settings = settings
  zfcore.server.port = settings.port
  zfcore.server.address = settings.address
  zfcore.server.reuseAddress = settings.reuseAddress
  zfcore.server.reusePort = settings.reusePort
  zfcore.server.trace = settings.trace
  zfcore.server.sslSettings = settings.sslSettings
  zfcore.server.keepAlive = settings.keepAlive
  zfcore.server.maxBodyLength = settings.maxBodyLength
  zfcore.server.tmpDir = settings.tmpDir
  zfcore.server.readBodyBuffer = settings.readBodyBuffer
  zfcore.server.tmpBodyDir = settings.tmpBodyDir

proc newZFCore*(): ZFCore {.gcsafe.} =
  ##
  ##  new zfcore:
  ##
  ##  try read settings.json if not exists will use default settings.
  ##
  var settingsJson = zfJsonSettings(){"core"}
  if not settingsJson.isNil:
    let settings = newSettings().configureSettings(settingsJson)
    
    result = ZFCore(
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
      settings: settings,
      tasksPool: initTable[string, TasksPoolAction]())

    result.initSystemTasksPool

  else:
    echo ""
    echo "Failed to load settings.json, using default settings."
    echo "place settings.json into config folder"
    echo ""
    let settings = newSettings()
    settings.appRootDir = getAppDir()
    result = ZFCore(
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
  ctx: zfbserver.HttpContext) {.gcsafe async.} =
  ##
  ##  return response if not found.
  ##

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
  ctx: zfbserver.HttpContext) {.gcsafe async.} =
  ##
  ##  send request data to the router
  ##
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

proc tasksPooling(self: ZFCore) {.gcsafe.} =
  ##
  ##  task pooling will check each 60 seconds
  ##
  while true:
    {.gcsafe.}:
      for k in self.tasksPool.keys:
        self.tasksPool[k].action(
          self.tasksPool[k].param.deepCopy
        )

    60000.sleep

#[
  this proc is private for main dispatch of request
]#
proc mainHandler(
  self: ZFCore,
  ctx: zfbserver.HttpContext) {.gcsafe async.} =
  ##
  ##  zfcore main handler for dispatch request.
  ##
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
  ##
  ##  start serve the zfcore sever.
  ##
  echo "Enjoy and take a cup of coffe :-)"

  # start cleanup thread
  spawn self.tasksPooling()

  self.server.serve proc (ctx: zfbserver.HttpContext) {.gcsafe async.} =
    await self.mainHandler(ctx)

# zfcore instance
let zfcoreInstance* {.global.} = newZFCore()

if not zfcoreInstance.settings.tmpDir.existsDir:
  zfcoreInstance.settings.tmpDir.createDir

###
### macros for the zfcore
###
macro routes*(group, body: untyped = nil): untyped =
  ##
  ##  routes macro:
  ##
  ##  register route
  ##  
  ##  routet("/api"):
  ##    # accessed with /api
  ##    get "/":
  ##      # html response
  ##      Http200.respHtml("hello")
  ##    # accessed with /api/register
  ##    post "/register":
  ##      # json response
  ##      Http200.resp(%*{"registered": true})
  ##
  var x: NimNode = body
  var routeGroup: string = ""
  
  if group.kind == nnkStmtList:
    x = group
  elif group.kind == nnkStrLit:
    routeGroup = group.strVal

  let stmtList = newStmtList()
  for child in x.children:
    if child.kind in [nnkCall, nnkCommand]:
      let childKind = (child[0].strVal).strip
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
        let route = routeGroup & (child[1].strVal).strip()
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

template emitServer*(jsonSettings: JsonNode = nil) =
  ##
  ##  start server:
  ##  routes:
  ##    get "/":
  ##      Http200.respHtml("Hello")
  ##
  ##    emitServer
  ##
  #nnkCommand.newTree(
  # newIdentNode("waitFor"),
  # nnkCall.newTree(
  #     nnkDotExpr.newTree(
  #       newIdentNode("zfcoreInstance"),
  #       newIdentNode("serve")
  #     )
  #   )
  #)

  if not jsonSettings.isNil:
    zfcoreInstance.applySettings(zfcoreInstance.settings.configureSettings(jsonSettings))

  waitFor zfcoreInstance.serve

macro resp*(
  httpCode: HttpCode,
  body: typed,
  headers: HttpHeaders = nil) =
  ##
  ##  resp macro:
  ##
  ##  routes:
  ##    get "/":
  ##      Http200.resp("hello", newHttpHeaders([("Content-Type", "text/html")]))
  ##

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

template resp*(
  respMsg: RespMsg,
  headers: HttpHeaders = nil): untyped =
  ##
  ##  resp
  ##  helper make easy to return json result
  ##  using RespMsg object
  ##
  respMsg.status.resp(%respMsg, headers)

macro respHtml*(
  httpCode: HttpCode,
  body: string,
  headers: HttpHeaders = nil) =
  ##
  ##  resp html macro:
  ##
  ##  routes:
  ##    get "/":
  ##      Http200.respHtml("hello", newHttpHeaders([("key", "val")]))
  ##
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

macro respRedirect*(
  redirectTo: string,
  httpCode: HttpCode = Http303) =
  ##
  ##  resp redirect macro:
  ##
  ##  routes:
  ##    get "/":
  ##      respRedirectTo("/home")
  ##
  nnkCommand.newTree(
    newIdentNode("await"),
    nnkCall.newTree(
      nnkDotExpr.newTree(
        newIdentNode("ctx"),
        newIdentNode("respRedirect")
      ),
      redirectTo,
      httpCode
    )
  )

macro setCookie*(
  cookies: StringTableRef,
  domain: string = "",
  path: string = "",
  expires: string = "",
  secure: bool = false,
  sameSite: string = "Lax",
  httpOnly: bool = true) =
  ##
  ##  get cookie:
  ##
  ##  route:
  ##    get "/setcookie":
  ##      setCookie({"name": "John", "city": "Monaco"}.newStringTable)
  ##      Http200.respHtml("set cookie")
  ##    get "/getcookie":
  ##      Http200.resp(%getCookie())
  ##
  nnkCall.newTree(
    nnkDotExpr.newTree(
      newIdentNode("ctx"),
      newIdentNode("setCookie")
    ),
    cookies,
    domain,
    path,
    expires,
    secure,
    sameSite,
    httpOnly
  )

macro getCookie*(): StringTableRef =
  ##
  ##  get cookie:
  ##
  ##  route:
  ##    get "/setcookie":
  ##      setCookie({"name": "John", "city": "Monaco"}.newStringTable)
  ##      Http200.respHtml("set cookie")
  ##    get "/getcookie":
  ##      Http200.resp(%getCookie())
  ##
  result = nnkCall.newTree(
    nnkDotExpr.newTree(
      newIdentNode("ctx"),
      newIdentNode("getCookie")
    )
  )

macro clearCookie*(cookies: StringTableRef) =
  ##
  ##  clear cookie:
  ##
  ##  route:
  ##    get "/setcookie":
  ##      setCookie({"name": "John", "city": "Monaco"}.newStringTable)
  ##      Http200.respHtml("set cookie")
  ##    get "/getcookie":
  ##      Http200.resp(%getCookie())
  ##    get "/clearcookie":
  ##      Http200.respHtml("clear cookie")
  ##
  nnkCall.newTree(
    nnkDotExpr.newTree(
      newIdentNode("ctx"),
      newIdentNode("clearCookie")
    ),
    cookies
  )

macro request*: Request =
  ##
  ##  get request information:
  ##
  ##  route:
  ##    get "/":
  ##      # req type is zfcore Request
  ##      let request = request
  ##      echo %request.headers
  ##      Http200.respHtml("Hello")
  ##
  result = nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("request")
  )

macro response*: Response =
  ##
  ##  get response information:
  ##
  ##  route:
  ##    get "/":
  ##      # res type is zfcore Response
  ##      echo %reponse.headers
  ##      Http200.respHtml("Hello")
  ##
  result = nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("response")
  )

macro config*: Settings =
  ##
  ##  get zfcore config information:
  ##
  ##  route:
  ##    get "/":
  ##      echo config
  ##      Http200.respHtml("Hello")
  ##
  result = nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("settings")
  )

macro client*: AsyncSocket =
  ##
  ##  get zfcore client information:
  ##
  ##  route:
  ##    get "/":
  ##      ## client is socket object
  ##      echo client.getPeerAddr()
  ##      Http200.respHtml("Hello")
  ##
  result = nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("client")
  )

macro ws*: WebSocket =
  ##  # websocket example :-)
  ##  get "/ws":
  ##    #
  ##    # ctx instance of HttpCtx exposed here :-)
  ##    # ws is shorthand of ctx.websocket
  ##    #
  ##    if not ws.isNil:
  ##      case ws.state:
  ##      of WSState.HandShake:
  ##        echo "HandShake state"
  ##        # this state will evaluate
  ##        # right before handshake process
  ##        # in here we can add the additionals response headers
  ##        # normaly we can skip this step
  ##        # about the handshake:
  ##        # handshake is using http headers
  ##        # this process is only happen 1 time
  ##        # after handshake success then the protocol will be switch to the websocket
  ##        # you can check the handshake header request in
  ##        # -> ws.handShakeReqHeaders this is the HtttpHeaders type
  ##        # and you also can add the additional headers information in the response handshake
  ##        # by adding the:
  ##        # -> ws.handShakeResHeaders
  ##      of WSState.Open:
  ##        echo "Open state"
  ##        # in this state all swaping process will accur
  ##        # like send or received message
  ##        case ws.statusCode:
  ##        of WSStatusCode.Ok:
  ##          case ws.inFrame.opCode:
  ##          of WSOpCode.TextFrame.uint8:
  ##            echo "Text frame received"
  ##            echo &"Fin {ws.inFrame.fin}"
  ##            echo &"Rsv1 {ws.inFrame.rsv1}"
  ##            echo &"Rsv2 {ws.inFrame.rsv2}"
  ##            echo &"Rsv3 {ws.inFrame.rsv3}"
  ##            echo &"OpCode {ws.inFrame.opCode}"
  ##            echo &"Mask {ws.inFrame.mask}"
  ##            echo &"Mask Key {ws.inFrame.maskKey}"
  ##            echo &"PayloadData {ws.inFrame.payloadData}"
  ##            echo &"PayloadLen {ws.inFrame.payloadLen}"
  ##            # how to show decoded data
  ##            # we can use the encodeDecode
  ##            echo ""
  ##            echo "Received data (decoded):"
  ##            echo ws.inFrame.encodeDecode()
  ##            # let send the data to the client
  ##            # set fin to 1 if this is independent message
  ##            # 1 meaning for read and finish
  ##            # if you want to use continues frame
  ##            # set it to 0
  ##            # for more information about web socket frame and protocol
  ##            # refer to the web socket documentation ro the RFC document
  ##            #
  ##            # WSOpCodeEnum:
  ##            # WSOpCode* = enum
  ##            #    ContinuationFrame = 0x0
  ##            #    TextFrame = 0x1
  ##            #    BinaryFrame = 0x2
  ##            #    ConnectionClose = 0x8
  ##            ws.outFrame = newWSFrame(
  ##              "This is from the endpoint :-)",
  ##              1,
  ##              WSOpCode.TextFrame.uint8)
  ##            await ws.send()
  ##          of WSOpCode.BinaryFrame.uint8:
  ##            echo "Binary frame received"
  ##          of WSOpCode.ContinuationFrame.uint8:
  ##            # the frame continues from previous frame
  ##            echo "Continuation frame received"
  ##          of WSOpCode.ConnectionClose.uint8:
  ##            echo "Connection close frame received"
  ##          else:
  ##              discard
  ##        else:
  ##            echo &"Failed status code {ws.statusCode}"
  ##      of WSState.Close:
  ##        echo "Close state"
  ##        # this state will execute if the connection close
  ##
  result = nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("webSocket")
  )

macro paramsData*: Table[string, string] =
  ##
  ##  get zfcore client information:
  ##
  ##  route:
  ##    # param from query string
  ##    # /param?hello=world
  ##    get "/param":
  ##      # echo %paramsData
  ##      Http200.respHtml("Hello")
  ##
  result = nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("params")
  )

macro reParamsData*: Table[string, seq[string]] =
  ##
  ##  get zfcore client information:
  ##
  ##  route:
  ##    # regex param
  ##    # accept /reparam/1
  ##    # accept /reparam/2
  ##    get "/reparam/<id:[0-9]>":
  ##      echo %reParamsData
  ##      Http200.respHtml("Hello")
  ##
  result = nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("reParams")
  )

macro formData*: FormData =
  ##
  ##  get zfcore client information:
  ##
  ##  route:
  ##    post "/formdata":
  ##      echo formData
  ##      Http200.respHtml("Hello")
  ##
  result = nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("formData")
  )

macro jsonData*: JsonNode =
  ##
  ##  get zfcore client information:
  ##
  ##  route:
  ##    post "/json":
  ##      echo jsonData
  ##      Http200.respHtml("Hello")
  ##
  result = nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("json")
  )

macro xmlData*: XmlNode =
  ##
  ##  get zfcore client information:
  ##
  ##  route:
  ##    post "/xml":
  ##      echo xmlData
  ##      Http200.respHtml("Hello")
  ##
  result = nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("xml")
  )

template siteUrl*: string =
  ##
  ##  get site url of the site
  ##
  ##
  zfbserver.getSiteUrl()

template buildMode*: string =
  ##
  ##  get build mode of the apps
  ##
  ##  will return string "debug" or "release"
  ##
  zfbserver.getBuildMode()

