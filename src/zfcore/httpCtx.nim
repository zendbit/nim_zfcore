#[
  ZendFlow web framework for nim language
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
  formData,
  zfblast


#[
  The field is widely used the zfblast HttpContext object but we add some field to its:
    url -> in ZendFlow we user uri3 from the nimble package
    params -> is table of the captured query string and path segment
    reParams -> is table of the captured regex match with the segment
    formData -> is FormData object and will capture if we use the multipart form
    json -> this will capture the application/json body from the post/put/patch method
    settings -> this is the shared settings
]#
type
  HttpCtx* = ref object of HttpContext
    params*: Table[string, string]
    reParams*: Table[string, seq[string]]
    formData*: FormData
    json*: JsonNode
    settings*: Settings

proc newHttpCtx*(ctx: HttpContext): HttpCtx =
  return HttpCtx(
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
  self: HttpCtx,
  cookies: StringTableRef,
  domain: string = "",
  path: string = "",
  expires: string = "",
  secure: bool = false) =

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

proc getCookie*(self: HttpCtx): StringTableRef =

  var cookie = self.request.headers.getOrDefault("cookie")
  if cookie != "":
    return parseCookies(cookie)

  return newStringTable()

proc clearCookie*(
  self: HttpCtx,
  cookies: StringTableRef) =

  self.setCookie(cookies, expires = "Thu, 01 Jan 1970 00:00:00 GMT")

proc resp*(
  self: HttpCtx,
  httpCode: HttpCode,
  body: string,
  headers: HttpHeaders = nil) =

  self.response.httpCode = httpCode
  self.response.body = body
  if not isNil(headers):
    for k, v in headers.pairs:
      if k.toLower == "content-type" and
        v.toLower.find("utf-8") == -1:
        self.response.headers[k] = v & "; charset=utf-8"

      else:
        self.response.headers[k] = v

  asyncCheck self.send(self)

proc resp*(
  self: HttpCtx,
  httpCode: HttpCode,
  body: JsonNode,
  headers: HttpHeaders = nil) =

  self.response.httpCode = httpCode
  self.response.headers["Content-Type"] = @["application/json", "charset=utf-8"]
  self.response.body = $body
  if not isNil(headers):
    for k, v in headers.pairs:
      self.response.headers[k] = v

  asyncCheck self.send(self)

proc respHtml*(
  self: HttpCtx,
  httpCode: HttpCode,
  body: string,
  headers: HttpHeaders = nil) =

  self.response.httpCode = httpCode
  self.response.headers["Content-Type"] = @["text/html", "charset=utf-8"]
  self.response.body = $body
  if not isNil(headers):
    for k, v in headers.pairs:
      self.response.headers[k] = v

  asyncCheck self.send(self)

proc respRedirect*(
  self: HttpCtx,
  redirectTo: string) =

  self.response.httpCode = Http303
  self.response.headers["Location"] = @[redirectTo]
  asyncCheck self.send(self)
