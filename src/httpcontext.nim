#[
  zfcore web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#
import
  asyncnet,
  tables,
  asyncdispatch,
  json,
  strtabs,
  cookies,
  strutils

# nimble
import
  uri3

# local
import
  settings,
  formdata,
  zfblast,
  websocket


type
  HttpContext* = ref object of zfblast.HttpContext
    # 
    # The field is widely used the zfblast HttpContext object but we add some field to its:
    # request -> Request object
    # response -> Response object
    # settings -> this is the shared settings
    #
    # params -> is table of the captured query string and path segment
    # reParams -> is table of the captured regex match with the segment
    # formData -> is FormData object and will capture if we use the multipart form
    # json -> this will capture the application/json body from the post/put/patch method
    #
    params*: Table[string, string]
    reParams*: Table[string, seq[string]]
    formData*: FormData
    json*: JsonNode
    settings*: Settings

proc newHttpContext*(ctx: zfblast.HttpContext): HttpContext =
  #
  # create new HttpContext from the zfblast HttpContext
  #
  return HttpContext(
    client: ctx.client,
    request: ctx.request,
    response: ctx.response,
    send: ctx.send,
    keepAliveMax: ctx.keepAliveMax,
    keepAliveTimeout: ctx.keepAliveTimeout,
    webSocket: ctx.webSocket,
    params: initTable[string, string](),
    reParams: initTable[string, seq[string]](),
    formData: newFormData(),
    json: JsonNode(),
    settings: newSettings())

proc setCookie*(
  self: HttpContext,
  cookies: StringTableRef,
  domain: string = "",
  path: string = "",
  expires: string = "",
  secure: bool = false) =
  #
  # create cookie
  # cookies is StringTableRef
  # setCookie({"username": "bond"}.newStringTable)
  #
  var cookieList: seq[string] = @[]
  for k, v in cookies:
    cookieList.add(k & "=" & v)

  if domain != "":
    cookieList.add("domain=" & domain)
  if path != "":
    cookieList.add("path=" & path)
  if expires != "":
    cookieList.add("expires=" & expires)
  if secure:
    cookieList.add("secure=" & $secure)

  self.response.headers.add("Set-Cookie", join(cookieList, ";"))

proc getCookie*(self: HttpContext): StringTableRef =
  #
  # get cookies, return StringTableRef
  # if ctx.getCookies().hasKey("username"):
  #   dosomethings
  #
  var cookie = self.request.headers.getOrDefault("cookie")
  if cookie != "":
    return parseCookies(cookie)

  return newStringTable()

proc clearCookie*(
  self: HttpContext,
  cookies: StringTableRef) =
  #
  # clear cookie
  # let cookies = ctx.getCookies
  # ctx.clearCookie(cookies)
  #
  self.setCookie(cookies, expires = "Thu, 01 Jan 1970 00:00:00 GMT")

proc resp*(
  self: HttpContext,
  httpCode: HttpCode,
  body: string,
  headers: HttpHeaders = nil) =
  #
  # response to the client
  # ctx.resp(Http200, "ok")
  #
  self.response.httpCode = httpCode
  self.response.body = body
  if not headers.isNil:
    for k, v in headers.pairs:
      if k.toLower == "content-type" and
        v.toLower.find("utf-8") == -1:
        self.response.headers[k] = v & "; charset=utf-8"

      else:
        self.response.headers[k] = v

  asyncCheck self.send(self)

proc resp*(
  self: HttpContext,
  httpCode: HttpCode,
  body: JsonNode,
  headers: HttpHeaders = nil) =
  #
  # response as application/json to the client
  # let msg = %*{"status": true}
  # ctx.resp(Http200, msg)
  #
  self.response.httpCode = httpCode
  self.response.headers["Content-Type"] = @["application/json"]
  self.response.body = $body
  if not headers.isNil:
    for k, v in headers.pairs:
      self.response.headers[k] = v

  asyncCheck self.send(self)

proc respHtml*(
  self: HttpContext,
  httpCode: HttpCode,
  body: string,
  headers: HttpHeaders = nil) =
  #
  # response as html to the client
  # ctx.respHtml(Http200, """<html><body>Nice...</body></html>""")
  #
  self.response.httpCode = httpCode
  self.response.headers["Content-Type"] = @["text/html", "charset=utf-8"]
  self.response.body = $body
  if not headers.isNil:
    for k, v in headers.pairs:
      self.response.headers[k] = v

  asyncCheck self.send(self)

proc respRedirect*(
  self: HttpContext,
  redirectTo: string) =
  #
  # response redirect to the client
  # ctx.respRedirect("https://google.com")
  #
  self.response.httpCode = Http303
  self.response.headers["Location"] = @[redirectTo]
  asyncCheck self.send(self)

export
  asyncnet,
  tables,
  asyncdispatch,
  json,
  strtabs,
  cookies,
  strutils

# nimble
export
  uri3

# local
export
  settings,
  Request,
  Response,
  websocket,
  formdata
