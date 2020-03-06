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
    uri3,
    tables,
    uri,
    asyncdispatch,
    asynchttpserver,
    unpure/packedjson,
    settings,
    cookies,
    strutils,
    strtabs,
    formData


#[
    The field is widely used the asynchttpserver Request object but we add some field to its:
        url -> in ZendFlow we user uri3 from the nimble package
        params -> is table of the captured query string and path segment
        reParams -> is table of the captured regex match with the segment
        formData -> is FormData object and will capture if we use the multipart form
        json -> this will capture the application/json body from the post/put/patch method
        settings -> this is the shared settings
        responseHeader -> headers will send on response to user
]#
type
    CtxReq* = ref object
        client*: AsyncSocket
        reqMethod*: HttpMethod
        headers*: HttpHeaders
        protocol*: tuple[orig: string, major, minor: int]
        url*: Uri3
        hostname*: string
        body*: string
        params*: Table[string, string]
        reParams*: Table[string, seq[string]]
        formData*: FormData
        json*: JsonNode
        settings*: Settings
        responseHeaders*: HttpHeaders

proc newCtxReq*(ctx: Request): CtxReq =
    return CtxReq(
        client: ctx.client,
        reqMethod: ctx.reqMethod,
        headers: ctx.headers,
        protocol: ctx.protocol,
        url: parseUri3($ctx.url),
        hostname: ctx.hostname,
        body: ctx.body,
        params: initTable[string, string](),
        reParams: initTable[string, seq[string]](),
        formData: newFormData(),
        json: JsonNode(),
        settings: newSettings(),
        responseHeaders: newHttpHeaders())

proc toRequest(self: CtxReq): Request =
    return Request(
        client: self.client,
        reqMethod: self.reqMethod,
        headers: self.headers,
        protocol: self.protocol,
        url: parseUri($self.url),
        hostname: self.hostname,
        body: self.body)

proc setCookie*(self: CtxReq, cookies: StringTableRef,
        domain: string = "", path: string = "", expires: string = "", secure: bool = false) =
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

    self.responseHeaders.add("Set-Cookie", join(cookieList, ";"))

proc getCookie*(self: CtxReq): StringTableRef =
    var cookie = self.headers.getOrDefault("cookie")
    if cookie != "":
        return parseCookies(cookie)

    return newStringTable()

proc clearCookie*(self: CtxReq, cookies: StringTableRef) =
    self.setCookie(cookies, expires = "Thu, 01 Jan 1970 00:00:00 GMT")

proc resp*(self: CtxReq, httpCode: HttpCode, content: string): Future[void] {.async.} =
    await respond(self.toRequest(), httpCode, content, self.responseHeaders)

proc resp*(self: CtxReq, httpCode: HttpCode, jnode: JsonNode): Future[void] {.async.} =
    self.responseHeaders.add("Content-Type", "application/json")
    await respond(self.toRequest(), httpCode, $jnode, self.responseHeaders)

proc render*(self: CtxReq, view: string): Future[void] {.async.} =
    self.responseHeaders.add("Content-Type", "text/html")
    await respond(self.toRequest(), Http200, render(self.settings.viewDir, view),
        self.responseHeaders)

proc respRedirect*(self: CtxReq, redirectTo: string): Future[void] {.async.} =
    self.responseHeaders.add("Location", redirectTo)
    await respond(self.toRequest(), Http303, "Go to " & redirectTo,
            self.responseHeaders)
