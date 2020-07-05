#[
  zfcore web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#
import nre except toSeq

import
  strutils,
  strformat,
  asyncdispatch,
  tables,
  json,
  os,
  httpcore,
  sugar

# nimble
import
  uri3

# local
import
  httpcontext,
  formdata,
  middleware,
  route,
  settings,
  mime,
  times
  
from zfblast import getHttpHeaderValues, trace

type
  Router* = ref object of Middleware
    #
    # router will contains registered Route
    # this is the hearts of zfcore
    # statisRoute is for file serving
    #
    routes: seq[Route]
    staticRoute: Route

proc newRouter*(): Router {.gcsafe.} =
  return Router(routes: @[])

proc matchesUri(
  self: Router,
  pathSeg: seq[string],
  uriSeg: seq[string]):
  tuple[
    success: bool,
    params: Table[string, string],
    reParams: Table[string, seq[string]]] =
  #
  # check if request url match with one of registered route
  #
  var success = true
  var reParams = initTable[string,seq[string]]()
  var params = initTable[string,string]()

  if pathSeg.len != uriSeg.len:
    success = false

  else:
    for i in 0..high(pathSeg):
      # check if matches with <tag-param>, ex: /home/<id>/index.html
      let currentPathSeg = pathSeg[i].decodeUri(false)
      let currentUriSeg = uriSeg[i].decodeUri(false)

      let paramTag = currentPathSeg.match(re"<([\w\W]+)>$")
      if paramTag.isSome:
        let reParamsTag = paramTag.get.captures[0].match(re"(\w+):re\[([\w\W]*)\]$")
        if reParamsTag.isSome:
          var reParamsSegmentTag: seq[string]
          let reParamToCapture = re reParamsTag.get.captures[1]
          let reParamCount = captureCount(reParamToCapture)
          let reParamCaptured = currentUriSeg.match(reParamToCapture)
          if reParamCount != 0:
            for i in 0..(reParamCount - 1):
              reParamsSegmentTag.add(reParamCaptured.get.captures[i])
            reParams.add(reParamsTag.get.captures[0], @ reParamsSegmentTag)
          
          else:
            success = false

        else:
          params.add(paramTag.get.captures[0], currentUriSeg)

      elif currentPathSeg != currentUriSeg:
        success = false

      # break and continue if current route not match
      if not success: break

  return (success: success, params: params, reParams: reParams)

proc getRoutes*(self: Router): seq[Route] =
  #
  # return registered routes
  #
  return self.routes

proc parseSegmentsFromPath(
  self: Router,
  path: string): seq[string] =
  #
  # get path segment from the given path
  #
  return parseUri3(path).getPathSegments()

proc parseUriToTable(
  self: Router,
  uri: string): Table[string, string] =
  #
  # This proc is private and will parse the uri to table form
  # ex: ?ok=true&hello=world will convert to {ok:true, hello:world}
  #
  var query = initTable[string, string]()
  var uriToParse = uri
  if uri.find("?") == -1: uriToParse = &"?{uriToParse}"
  for q in uriToParse.parseUri3().getAllQueries():
    query.add(q[0], q[1].decodeUri())

  if query.len > 0:
    return query

proc mapContentype(
  self: Router,
  ctx: HttpContext) =
  # This proc is private for mapt the content type
  # HttpPost, HttpPut, HttpPatch will auto parse and extract the request, including the uploaded files
  # uploaded files will save to tmp folder

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

proc handleStaticRoute(
  self: Router,
  ctx: HttpContext):
  Future[tuple[
    found: bool,
    filePath: string,
    contentType: string]] {.async.} =
  # Handle static resource, this should be only allow get method
  # all static resource should be access using prefix /s/
  # example static di is in this form:
  #   www/styles/*.css
  #   www/js/*.js
  #   www/img/*.jpg
  #   etc
  # we can call from the url using this form:
  #   /s/style/*.css
  #   /s/js/*.js
  #   /s/img/*.jpg
  #   etc

  if not self.staticRoute.isNil:
    # get route from the path
    var routePath = self.staticRoute.path.decodeUri()
    # get static path from the request url
    var staticPath = ctx.request.url.getPath().decodeUri()
    if ctx.request.httpMethod == HttpGet:
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
          #var ext: array[1, string]
          #if match(staticPath, re"[\w\W]+\.([\w]+)$", ext):
          let ext = staticPath.match(re"[\w\W]+\.([\w]+)$")
          if ext.isSome:
            # if extension is defined then try to search the contentType
            let mimeType = newMimeType().getMimeType(
              ("." & ext.get.captures[0]).toLower)
            # override the contentType if we found it
            if mimeType != "":
              contentType = mimeType

          return (
            found: true,
            filePath: staticSearchDir,
            contentType: contentType)

proc handleDynamicRoute(
  self: Router,
  ctx: HttpContext): Future[void] {.async.} =
  # 
  # execute middleware before routing
  # handle dynamic route
  #
  if await self.execBeforeRoute(ctx): return
  # call static route before the dynamic route
  let (staticFound, staticFilePath, staticContentType) =
    await self.handleStaticRoute(ctx)
  # map content type
  self.mapContentype(ctx)

  # route to potensial uri
  # also extract the uri parameter
  let ctxSegments = self.parseSegmentsFromPath(ctx.request.url.getPath())
  #var exec: proc (ctx: HttpContext): Future[void] {.gcsafe.}
  var route: Route
  for r in self.routes:
    let matchesUri = self.matchesUri(r.segments, ctxSegments)
    if r.httpMethod == ctx.request.httpMethod and
      matchesUri.success:
      route = r
      for k, v in matchesUri.params:
        ctx.params.add(k, v)

      for qStr in ctx.request.url.getAllQueries():
        ctx.params.add(qStr[0], qStr[1].decodeUri())

      ctx.reParams = matchesUri.reParams

      break

  if route != nil:
    # execute middleware after routing before response
    if await self.execAfterRoute(ctx, route): return

    # execute route callback
    await route.thenDo(ctx)

  elif staticFound:
    ctx.response.headers["Content-Type"] = staticContentType & "; charset=utf-8"
    if getHttpHeaderValues("Last-Modified", ctx.response.headers) == "":
      ctx.response.headers["Last-Modified"] =
        format(utc(getFileInfo(staticFilePath).lastAccessTime),
          "ddd, dd MMM yyyy HH:mm:ss") & " GMT"

    ctx.resp(Http200, staticFilePath.open().readAll())

  else:
    # default response if route does not match
    ctx.resp(Http404, &"Resource not found {ctx.request.url.getPath()}")

proc executeProc*(
  self: Router,
  ctx: zfblast.HttpContext,
  settings: Settings): Future[void] {.async.} =
  #
  # This proc will execute the registered callback procedure in route list.
  # asynchttpserver Request will convert to HttpContext.
  # beforeRoute and afterRoute middleware will evaluated here
  #
  try:
    var httpCtx = ctx.newHttpContext
    httpCtx.settings = settings

    await self.handleDynamicRoute(httpCtx)
  except Exception as ex:
    echo ex.msg

proc static*(
  self: Router,
  path: string) =

  self.staticRoute = Route(
    path: path,
    httpMethod: HttpGet,
    thenDo: nil,
    segments: self.parseSegmentsFromPath(path))

proc get*(
  self: Router,
  path: string,
  thenDo: (ctx: HttpContext) -> Future[void]) =
  #
  # let zf = newZfCore()
  #
  ### Register the post route to the framework
  ### example with regex to extract the segment
  ### this regex will match with /home/123_12345/test
  ### the regex will capture ids -> @["123", "12345"]
  ### the <body> parameter will capture body -> test
  # zf.r.get("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #   echo "Welcome home"
  #   echo $ctx.reParams["ids"]
  #   echo $ctx.params["body"]
  #   await ctx.resp(Http200, "Hello World"))
  #
  # ### without regex
  # ### will accept from /home
  # zf.r.get("/home", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #
  #   #### your code here
  #
  #   await ctx.resp(Http200, "Hello World"))
  #
  # ### start the server
  #
  # zf.serve()
  #
  #
  self.routes.add(Route(path: path,
    httpMethod: HttpGet,
    thenDo: thenDo,
    segments: self.parseSegmentsFromPath(path)))

proc post*(
  self: Router,
  path: string,
  thenDo: (ctx: HttpContext) -> Future[void]) =
  #
  # let zf = newZfCore()
  #
  ### Register the post route to the framework
  ### example with regex to extract the segment
  ### this regex will match with /home/123_12345/test
  ### the regex will capture ids -> @["123", "12345"]
  ### the <body> parameter will capture body -> test
  # zf.r.post("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #   echo "Welcome home"
  #   echo $ctx.reParams["ids"]
  #   echo $ctx.params["body"]
  #   await ctx.resp(Http200, "Hello World"))
  #
  ### without regex
  ### will accept from /home
  # zf.r.post("/home", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #
  #   #### your code here
  #
  #   await ctx.resp(Http200, "Hello World"))
  #
  # ### start the server
  #
  # zf.serve()
  #
  #
  self.routes.add(Route(path: path,
    httpMethod: HttpPost,
    thenDo: thenDo,
    segments: self.parseSegmentsFromPath(path)))

proc put*(
  self: Router,
  path: string,
  thenDo: (ctx: HttpContext) -> Future[void]) =
  #
  # let zf = newZfCore()
  #
  ### Register the post route to the framework
  ### example with regex to extract the segment
  ### this regex will match with /home/123_12345/test
  ### the regex will capture ids -> @["123", "12345"]
  ### the <body> parameter will capture body -> test
  # zf.r.put("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #   echo "Welcome home"
  #   echo $ctx.reParams["ids"]
  #   echo $ctx.params["body"]
  #   await ctx.resp(Http200, "Hello World"))
  #
  ### without regex
  ### will accept from /home
  # zf.r.put("/home", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #
  #   #### your code here
  #
  #   await ctx.resp(Http200, "Hello World"))
  #
  # ### start the server
  #
  # zf.serve()
  #
  #
  self.routes.add(Route(path: path,
    httpMethod: HttpPut,
    thenDo: thenDo,
    segments: self.parseSegmentsFromPath(path)))

proc delete*(
  self: Router,
  path: string,
  thenDo: (ctx: HttpContext) -> Future[void]) =
  #
  # let zf = newZfCore()
  #
  ### Register the post route to the framework
  ### example with regex to extract the segment
  ### this regex will match with /home/123_12345/test
  ### the regex will capture ids -> @["123", "12345"]
  ### the <body> parameter will capture body -> test
  # zf.r.delete("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #   echo "Welcome home"
  #   echo $ctx.reParams["ids"]
  #   echo $ctx.params["body"]
  #   await ctx.resp(Http200, "Hello World"))
  #
  ### without regex
  ### will accept from /home
  # zf.r.delete("/home", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #
  #   #### your code here
  #
  #   await ctx.resp(Http200, "Hello World"))
  #
  ### start the server
  #
  # zf.serve()
  #
  #
  self.routes.add(Route(path: path,
    httpMethod: HttpDelete,
    thenDo: thenDo,
    segments: self.parseSegmentsFromPath(path)))

proc patch*(
  self: Router,
  path: string,
  thenDo: (ctx: HttpContext) -> Future[void]) =
  #
  # let zf = newZfCore()
  #
  ### Register the post route to the framework
  ### example with regex to extract the segment
  ### this regex will match with /home/123_12345/test
  ### the regex will capture ids -> @["123", "12345"]
  ### the <body> parameter will capture body -> test
  # zf.r.patch("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #   echo "Welcome home"
  #   echo $ctx.reParams["ids"]
  #   echo $ctx.params["body"]
  #   await ctx.resp(Http200, "Hello World"))
  #
  ### without regex
  ### will accept from /home
  # zf.r.patch("/home", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #
  #   #### your code here
  #
  #   await ctx.resp(Http200, "Hello World"))
  #
  ### start the server
  #
  # zf.serve()
  #
  #
  self.routes.add(Route(path: path,
    httpMethod: HttpPatch,
    thenDo: thenDo,
    segments: self.parseSegmentsFromPath(path)))

proc head*(
  self: Router,
  path: string,
  thenDo: (ctx: HttpContext) -> Future[void]) =
  #
  # let zf = newZfCore()
  #
  ### Register the post route to the framework
  ### example with regex to extract the segment
  ### this regex will match with /home/123_12345/test
  ### the regex will capture ids -> @["123", "12345"]
  ### the <body> parameter will capture body -> test
  # zf.r.get("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #   echo "Welcome home"
  #   echo $ctx.reParams["ids"]
  #   echo $ctx.params["body"]
  #   await ctx.resp(Http200, "Hello World"))
  #
  ### without regex
  ### will accept from /home
  # zf.r.get("/home", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #
  #   #### your code here
  #
  #   await ctx.resp(Http200, "Hello World"))
  #
  ### start the server
  #
  # zf.serve()
  #
  #
  self.routes.add(Route(path: path,
    httpMethod: HttpHead,
    thenDo: thenDo,
    segments: self.parseSegmentsFromPath(path)))

proc options*(
  self: Router,
  path: string,
  thenDo: (ctx: HttpContext) -> Future[void]) =
  #
  # let zf = newZfCore()
  #
  ### Register the post route to the framework
  ### example with regex to extract the segment
  ### this regex will match with /home/123_12345/test
  ### the regex will capture ids -> @["123", "12345"]
  ### the <body> parameter will capture body -> test
  # zf.r.options("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #   echo "Welcome home"
  #   echo $ctx.reParams["ids"]
  #   echo $ctx.params["body"]
  #   await ctx.resp(Http200, "Hello World"))
  #
  ### without regex
  ### will accept from /home
  # zf.r.options("/home", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #
  #   #### your code here
  #
  #   await ctx.resp(Http200, "Hello World"))
  #
  ### start the server
  #
  # zf.serve()
  #
  #
  self.routes.add(Route(path: path,
    httpMethod: HttpOptions,
    thenDo: thenDo,
    segments: self.parseSegmentsFromPath(path)))

proc trace*(
  self: Router,
  path: string,
  thenDo: (ctx: HttpContext) -> Future[void]) =
  #
  # let zf = newZfCore()
  #
  ### Register the post route to the framework
  ### example with regex to extract the segment
  ### this regex will match with /home/123_12345/test
  ### the regex will capture ids -> @["123", "12345"]
  ### the <body> parameter will capture body -> test
  # zf.r.get("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #   echo "Welcome home"
  #   echo $ctx.reParams["ids"]
  #   echo $ctx.params["body"]
  #   await ctx.resp(Http200, "Hello World"))
  #
  ### without regex
  ### will accept from /home
  # zf.r.get("/home", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #
  #   #### your code here
  #
  #   await ctx.resp(Http200, "Hello World"))
  #
  ### start the server
  #
  # zf.serve()
  #
  #
  self.routes.add(Route(path: path,
    httpMethod: HttpTrace,
    thenDo: thenDo,
    segments: self.parseSegmentsFromPath(path)))

proc connect*(
  self: Router,
  path: string,
  thenDo: (ctx: HttpContext) -> Future[void]) =
  #
  # let zf = newZfCore()
  #
  ### Register the post route to the framework
  ### example with regex to extract the segment
  ### this regex will match with /home/123_12345/test
  ### the regex will capture ids -> @["123", "12345"]
  ### the <body> parameter will capture body -> test
  # zf.r.get("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #   echo "Welcome home"
  #   echo $ctx.reParams["ids"]
  #   echo $ctx.params["body"]
  #   await ctx.resp(Http200, "Hello World"))
  #
  ### without regex
  ### will accept from /home
  # zf.r.get("/home", proc (
  #   ctx: HttpContext): Future[void] {.async.} =
  #
  #   #### your code here
  #
  #   await ctx.resp(Http200, "Hello World"))
  #
  ### start the server
  #
  # zf.serve()
  #
  #
  self.routes.add(Route(path: path,
    httpMethod: HttpConnect,
    thenDo: thenDo,
    segments: self.parseSegmentsFromPath(path)))

export
  middleware
