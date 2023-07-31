##
##  zfcore web framework for nim language
##  This framework if free to use and to modify
##  License: BSD
##  Author: Amru Rosyada
##  Email: amru.rosyada@gmail.com
##  Git: https://github.com/zendbit/nim.zfcore
##

import mimetypes
import regex

export mimetypes

# nimble
import
  uri3,
  respmsg,
  zfblast/Server as zfbserver
from zfblast/Server import getValues, trace

export
  trace,
  getValues

# local
import
  httpcontext,
  formdata,
  middleware,
  route,
  settings

export
  httpcontext,
  formdata,
  middleware,
  route,
  settings

type
  Router* = ref object of Middleware
    ##
    ##  router type:
    ##
    ##  router will contains registered Route
    ##  this is the hearts of zfcore
    ##  statisRoute is for file serving
    ##
    routes*: seq[Route]
    staticRoute*: Route

proc newRouter*(): Router {.gcsafe.} =
  ##
  ##  new router
  ##
  result = Router(routes: @[])

proc clearPath(path: string): string =
  result = path
  if path.endsWith("/") and path != "/":
    result = path.substr(0, path.high - 1)

proc getRoutes*(self: Router): seq[Route] =
  ##
  ##  get routes:
  ##
  ##  return registered routes.
  ##
  result = self.routes

proc matchesUri(
  pathSeg: seq[string],
  uriSeg: seq[string]):
  tuple[
    success: bool,
    params: Table[string, string],
    reParams: Table[string, seq[string]]] =
  ##
  ##  matches url:
  ##
  ##  check if request url match with one of registered route.
  ##
  var success = true
  var reParams = initTable[string,seq[string]]()
  var params = initTable[string,string]()

  if pathSeg.len != uriSeg.len:
    success = false

  elif pathSeg.join("") != uriSeg.join(""):
    for i in 0..high(pathSeg):
      # check if matches with <tag-param>, ex: /home/<id>/index.html
      let currentPathSeg = pathSeg[i].decodeUri(false)
      let currentUriSeg = uriSeg[i].decodeUri(false)

      #let paramTag = currentPathSeg.match(re"<([\w\W]+)>$")
      var regMatch: RegexMatch
      #let paramTag = currentPathSeg.match(re"<([\w\W]+)>$", regMatch)
      #if paramTag.isSome:
      #if paramTag:
      ##
      ##  check segment with /api/<capturedSegment>/test
      ##
      if currentPathSeg.match(re"<([\w\W]+)>$", regMatch):
        let capturedSeg = regMatch.groupFirstCapture(0, currentPathSeg)
        ##
        ##  check if segment contains regex pattern
        ##  try to capture given regex
        ##
        if capturedSeg.match(re"(\w+):re\[([\w\W]*)\]$", regMatch):
          ##
          ##  capture pattern with regex
          ##  ex: /req/<ids:re[([0-9]+)_([0-9]+)]>
          ##
          let capturedReSegIds = regMatch.groupFirstCapture(0, capturedSeg)
          let capturedReSeg = regMatch.groupFirstCapture(1, capturedSeg)
          var capturedReParamSeg: seq[string]

          var capturedParamReSeg: seq[string]
          if currentUriSeg.match(re capturedReSeg, regMatch):
            for i in 0..regMatch.groupsCount() - 1:
              capturedParamReSeg.add(regMatch.groupFirstCapture(i, currentUriSeg))
            reParams.add(capturedReSegIds, @ capturedParamReSeg)
          else:
            success = false
        else:
          params.add(capturedSeg, currentUriSeg)
      elif currentPathSeg != currentUriSeg:
        success = false

      ##
      ##  break and continue if current route not match
      ##
      if not success: break

  result = (success: success, params: params, reParams: reParams)

proc parseSegmentsFromPath(path: string): seq[string] =
  ##
  ##  parse segment from path:
  ##
  ##  get path segment from the given path.
  ##
  result = parseUri3(path).getPathSegments()

proc handleStaticRoute(
  self: Router,
  ctx: httpcontext.HttpContext):
  tuple[
    found: bool,
    filePath: string,
    contentType: string] {.gcsafe.} =
  ##
  ##  handle static route:
  ##
  ##  Handle static resource, this should be only allow get method
  ##  all static resource should be access using prefix /s/
  ##  example static di is in this form:
  ##    www/styles/*.css
  ##    www/js/*.js
  ##    www/img/*.jpg
  ##    etc
  ##  we can call from the url using this form:
  ##    /s/style/*.css
  ##    /s/js/*.js
  ##    /s/img/*.jpg
  ##    etc
  ##
  if not self.staticRoute.isNil:
    # get route from the path
    var routePath = self.staticRoute.path.decodeUri()
    # get static path from the request url
    var staticPath = ctx.request.url.getPath().decodeUri()
    if ctx.request.httpMethod in [HttpGet, HttpHead]:
      # only if static path from the request url start with the route path
      if staticPath.startsWith(routePath) and
        routePath != staticPath:
        # static dir will search under staticDir in settings section
        let staticSearchDir = ctx.settings.staticDir & staticPath
        if staticSearchDir.fileExists:
          # define contentType of the file
          # default is "application/octet-stream"
          var contentType = "application/octet-stream"
          # define extension of the requested file
          var regMatch: RegexMatch
          if staticPath.match(re"[\w\W]+\.([\w]+)$", regMatch):
            let ext = regMatch.groupFirstCapture(0, staticPath)
            # if extension is defined then try to search the contentType
            let mimeType = newMimeTypes().getMimeType(
              ext.toLower())
            # override the contentType if we found it
            if mimeType != "":
              contentType = mimeType

          result = (
            found: true,
            filePath: staticSearchDir,
            contentType: contentType)

proc handleDynamicRoute(
  self: Router,
  ctx: httpcontext.HttpContext) {.gcsafe async.} =
  ##
  ##  handle dynamic route:
  ##
  ##  handle dynamic route from the path, midleware action, static routes.
  ##

  ##  redirect to base url if last page contains /
  let reqPath = ctx.request.url.getPath()
  if reqPath.endsWith("/") and reqPath != "/":
    ctx.request.url = ($ctx.request.url).clearPath.parseURI3

  # map content type
  # extract and map based on content type
  ctx.mapContentype
  
  # 
  # execute middleware before routing
  # handle dynamic route
  #
  #if self.execBeforeRoute(ctx): return
  for pre in self.beforeRoutes:
    if await pre(ctx): return

  # call static route before the dynamic route
  let (staticFound, staticFilePath, staticContentType) =
    self.handleStaticRoute(ctx)
  if staticFound:
    # set static file path
    ctx.staticFile(staticFilePath)

  # route to potensial uri
  # also extract the uri parameter
  let ctxSegments = reqPath.parseSegmentsFromPath
  #var exec: proc (ctx: HttpContext): Future[void] {.gcsafe.}
  var route: Route
  for r in self.routes:
    let matchesUri = r.segments.matchesUri(ctxSegments)
    if r.httpMethod == ctx.request.httpMethod and
      matchesUri.success:
      route = r
      for k, v in matchesUri.params:
        ctx.params.add(k, v)

      for qStr in ctx.request.url.getAllQueries():
        ctx.params.add(qStr[0], qStr[1].decodeUri())

      ctx.reParams = matchesUri.reParams

  if not route.isNil or staticFound:
    # execute middleware after routing before response
    #if self.execAfterRoute(ctx, route): return
    for post in self.afterRoutes:
      if await post(ctx, route): return

  if staticFound:
    let fileInfo = staticFilePath.getFileInfo
    ctx.response.headers["Content-Type"] = staticContentType
    if ctx.response.headers.getValues("Cache-Control") == "":
      ctx.response.headers["Cache-Control"] = "must-revalidate"
    if ctx.response.headers.getValues("Last-Modified") == "":
      ctx.response.headers["Last-Modified"] =
        fileInfo.lastWriteTime.utc().format("ddd, dd MMM yyyy HH:mm:ss".initTimeFormat) & " GMT"
    if ctx.response.headers.getValues("Date") == "":
      ctx.response.headers["Date"] =
        fileInfo.lastAccessTime.utc().format("ddd, dd MMM yyyy HH:mm:ss".initTimeFormat) & " GMT"

    # check if header contains Range
    let headRange = ctx.request.headers.getValues("Range")
    if ctx.isSupportGz(staticContentType) or headRange == "":
      let staticFile = staticFilePath.open
      if ctx.settings.maxResponseBodyLength >= staticFile.getFileSize:
        await ctx.resp(Http200, staticFile.readAll)
      else:
        await ctx.resp(Http406, %newRespMsg(
          success = false,
          error = %*{
            "msg": &"use Range header (partial request) " &
            &"for response larger than {ctx.settings.maxResponseBodyLength div (1024*1024)} MB. " &
            "https://developer.mozilla.org/en-US/docs/Web/HTTP/Range_requests"}))
      staticFile.close
    else:
      let contentRange = ctx.getContentRange
      if contentRange.content != "":
        await ctx.resp(Http206, contentRange.content, contentRange.headers)
      else:
        await ctx.resp(Http406, %contentRange.errMsg)

  elif not route.isNil:
    # execute route callback
    await route.thenDo(ctx)

  else:
    # default response if route does not match
    await ctx.resp(Http404, %newRespMsg(error = %*{
      "msg": "not found {ctx.request.url.getPath()}."}))

proc executeProc*(
  self: Router,
  ctx: zfbserver.HttpContext,
  settings: Settings) {.gcsafe async.} =
  ##
  ##  execute proc:
  ##
  ##  This proc will execute the registered callback procedure in route list.
  ##  asynchttpserver Request will convert to httpcontext.
  ##  beforeRoute and afterRoute middleware will evaluated here
  ##
  try:
    var httpCtx = ctx.newHttpContext
    httpCtx.settings = settings
    await self.handleDynamicRoute(httpCtx)
  except Exception as ex:
    echo ex.msg
    let respMsg = newRespMsg(success=false,
      error = %*{"status": false, "error": ex.msg.split("\n")},
      data = %*{})
    ctx.response.headers["Content-Type"] = "application/json"
    ctx.response.body = (%respMsg).pretty(2)
    ctx.response.httpCode = Http500
    await ctx.send(ctx)

proc static*(
  self: Router,
  path: string) {.gcsafe.} =
  ##
  ##  static:
  ##
  ##  register static route.
  ##
  let path = path.clearPath
  self.staticRoute = Route(
    path: path,
    httpMethod: HttpGet,
    thenDo: nil,
    segments: path.parseSegmentsFromPath)

proc get*(
  self: Router,
  path: string,
  thenDo: proc (ctx: httpcontext.HttpContext) {.gcsafe async.}) {.gcsafe.} =
  ##
  ##  register get route:
  ##
  ##  let zf = newTZfCore()
  ##
  ##  Register the post route to the framework
  ##  example with regex to extract the segment
  ##  this regex will match with /home/123_12345/test
  ##  the regex will capture ids -> @["123", "12345"]
  ##  the <body> parameter will capture body -> test
  ##
  ##  zf.r.get("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##    echo "Welcome home"
  ##    echo $ctx.reParams["ids"]
  ##    echo $ctx.params["body"]
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### without regex
  ##  ### will accept from /home
  ##  zf.r.get("/home", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##
  ##    #### your code here
  ##
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### start the server
  ##
  ##  zf.serve()
  ##
  let path = path.clearPath
  self.routes.add(Route(path: path,
    httpMethod: HttpGet,
    thenDo: thenDo,
    segments: path.parseSegmentsFromPath))

proc post*(
  self: Router,
  path: string,
  thenDo: proc (ctx: httpcontext.HttpContext) {.gcsafe async.}) {.gcsafe.} =
  ##
  ##  register post route:
  ##
  ##  let zf = newTZfCore()
  ##
  ##  Register the post route to the framework
  ##  example with regex to extract the segment
  ##  this regex will match with /home/123_12345/test
  ##  the regex will capture ids -> @["123", "12345"]
  ##  the <body> parameter will capture body -> test
  ##
  ##  zf.r.post("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##    echo "Welcome home"
  ##    echo $ctx.reParams["ids"]
  ##    echo $ctx.params["body"]
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### without regex
  ##  ### will accept from /home
  ##  zf.r.post("/home", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##
  ##    #### your code here
  ##
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### start the server
  ##
  ##  zf.serve()
  ##
  let path = path.clearPath
  self.routes.add(Route(path: path,
    httpMethod: HttpPost,
    thenDo: thenDo,
    segments: path.parseSegmentsFromPath))

proc put*(
  self: Router,
  path: string,
  thenDo: proc (ctx: httpcontext.HttpContext) {.gcsafe async.}) {.gcsafe.} =
  ##
  ##  register put route:
  ##
  ##  let zf = newTZfCore()
  ##
  ##  Register the post route to the framework
  ##  example with regex to extract the segment
  ##  this regex will match with /home/123_12345/test
  ##  the regex will capture ids -> @["123", "12345"]
  ##  the <body> parameter will capture body -> test
  ##
  ##  zf.r.put("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##    echo "Welcome home"
  ##    echo $ctx.reParams["ids"]
  ##    echo $ctx.params["body"]
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### without regex
  ##  ### will accept from /home
  ##  zf.r.put("/home", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##
  ##    #### your code here
  ##
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### start the server
  ##
  ##  zf.serve()
  ##
  let path = path.clearPath
  self.routes.add(Route(path: path,
    httpMethod: HttpPut,
    thenDo: thenDo,
    segments: path.parseSegmentsFromPath))

proc delete*(
  self: Router,
  path: string,
  thenDo: proc (ctx: httpcontext.HttpContext) {.gcsafe async.}) {.gcsafe.} =
  ##
  ##  register delete route:
  ##
  ##  let zf = newTZfCore()
  ##
  ##  Register the post route to the framework
  ##  example with regex to extract the segment
  ##  this regex will match with /home/123_12345/test
  ##  the regex will capture ids -> @["123", "12345"]
  ##  the <body> parameter will capture body -> test
  ##
  ##  zf.r.delete("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##    echo "Welcome home"
  ##    echo $ctx.reParams["ids"]
  ##    echo $ctx.params["body"]
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### without regex
  ##  ### will accept from /home
  ##  zf.r.delete("/home", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##
  ##    #### your code here
  ##
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### start the server
  ##
  ##  zf.serve()
  ##
  let path = path.clearPath
  self.routes.add(Route(path: path,
    httpMethod: HttpDelete,
    thenDo: thenDo,
    segments: path.parseSegmentsFromPath))

proc patch*(
  self: Router,
  path: string,
  thenDo: proc (ctx: httpcontext.HttpContext) {.gcsafe async.}) {.gcsafe.} =
  ##
  ##  register patch route:
  ##
  ##  let zf = newTZfCore()
  ##
  ##  Register the post route to the framework
  ##  example with regex to extract the segment
  ##  this regex will match with /home/123_12345/test
  ##  the regex will capture ids -> @["123", "12345"]
  ##  the <body> parameter will capture body -> test
  ##
  ##  zf.r.patch("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##    echo "Welcome home"
  ##    echo $ctx.reParams["ids"]
  ##    echo $ctx.params["body"]
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### without regex
  ##  ### will accept from /home
  ##  zf.r.patch("/home", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##
  ##    #### your code here
  ##
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### start the server
  ##
  ##  zf.serve()
  ##
  let path = path.clearPath
  self.routes.add(Route(path: path,
    httpMethod: HttpPatch,
    thenDo: thenDo,
    segments: path.parseSegmentsFromPath))

proc head*(
  self: Router,
  path: string,
  thenDo: proc (ctx: httpcontext.HttpContext) {.gcsafe async.}) {.gcsafe.} =
  ##
  ##  register head route:
  ##
  ##  let zf = newTZfCore()
  ##
  ##  Register the post route to the framework
  ##  example with regex to extract the segment
  ##  this regex will match with /home/123_12345/test
  ##  the regex will capture ids -> @["123", "12345"]
  ##  the <body> parameter will capture body -> test
  ##
  ##  zf.r.head("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##    echo "Welcome home"
  ##    echo $ctx.reParams["ids"]
  ##    echo $ctx.params["body"]
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### without regex
  ##  ### will accept from /home
  ##  zf.r.head("/home", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##
  ##    #### your code here
  ##
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### start the server
  ##
  ##  zf.serve()
  ##
  let path = path.clearPath
  self.routes.add(Route(path: path,
    httpMethod: HttpHead,
    thenDo: thenDo,
    segments: path.parseSegmentsFromPath))

proc options*(
  self: Router,
  path: string,
  thenDo: proc (ctx: httpcontext.HttpContext) {.gcsafe async.}) {.gcsafe.}=
  ##
  ##  register options route:
  ##
  ##  let zf = newTZfCore()
  ##
  ##  Register the post route to the framework
  ##  example with regex to extract the segment
  ##  this regex will match with /home/123_12345/test
  ##  the regex will capture ids -> @["123", "12345"]
  ##  the <body> parameter will capture body -> test
  ##
  ##  zf.r.options("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##    echo "Welcome home"
  ##    echo $ctx.reParams["ids"]
  ##    echo $ctx.params["body"]
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### without regex
  ##  ### will accept from /home
  ##  zf.r.options("/home", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##
  ##    #### your code here
  ##
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### start the server
  ##
  ##  zf.serve()
  ##
  let path = path.clearPath
  self.routes.add(Route(path: path,
    httpMethod: HttpOptions,
    thenDo: thenDo,
    segments: path.parseSegmentsFromPath))

proc trace*(
  self: Router,
  path: string,
  thenDo: proc (ctx: httpcontext.HttpContext) {.gcsafe async.}) {.gcsafe.} =
  ##
  ##  register trace route:
  ##
  ##  let zf = newTZfCore()
  ##
  ##  Register the post route to the framework
  ##  example with regex to extract the segment
  ##  this regex will match with /home/123_12345/test
  ##  the regex will capture ids -> @["123", "12345"]
  ##  the <body> parameter will capture body -> test
  ##
  ##  zf.r.trace("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##    echo "Welcome home"
  ##    echo $ctx.reParams["ids"]
  ##    echo $ctx.params["body"]
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### without regex
  ##  ### will accept from /home
  ##  zf.r.trace("/home", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##
  ##    #### your code here
  ##
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### start the server
  ##
  ##  zf.serve()
  ##
  let path = path.clearPath
  self.routes.add(Route(path: path,
    httpMethod: HttpTrace,
    thenDo: thenDo,
    segments: path.parseSegmentsFromPath))

proc connect*(
  self: Router,
  path: string,
  thenDo: proc (ctx: httpcontext.HttpContext) {.gcsafe async.}) {.gcsafe.} =
  ##
  ##  register connect route:
  ##
  ##  let zf = newTZfCore()
  ##
  ##  Register the post route to the framework
  ##  example with regex to extract the segment
  ##  this regex will match with /home/123_12345/test
  ##  the regex will capture ids -> @["123", "12345"]
  ##  the <body> parameter will capture body -> test
  ##
  ##  zf.r.connect("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##    echo "Welcome home"
  ##    echo $ctx.reParams["ids"]
  ##    echo $ctx.params["body"]
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### without regex
  ##  ### will accept from /home
  ##  zf.r.connect("/home", proc (
  ##    ctx: HttpContext): Future[void] {.async.} =
  ##
  ##    #### your code here
  ##
  ##    ctx.resp(Http200, "Hello World"))
  ##
  ##  ### start the server
  ##
  ##  zf.serve()
  ##
  let path = path.clearPath
  self.routes.add(Route(path: path,
    httpMethod: HttpConnect,
    thenDo: thenDo,
    segments: path.parseSegmentsFromPath))

