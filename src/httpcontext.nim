#[
  zfcore web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#
import asyncnet, tables, asyncdispatch, strtabs, cookies,
  strutils, httpcore, os, times, base64, strformat, json
export asyncnet, tables, asyncdispatch, strtabs, cookies,
  strutils, httpcore, os, times, base64, strformat, json

# nimble
import uri3, zip/gzipfiles, stdext/strutils_ext
export uri3, gzipfiles, strutils_ext

# local
import settings, formdata, websocket, apimsg
export settings, formdata, websocket, apimsg

import zfblast
export send, getHttpHeaderValues, trace, Response, Request

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
    staticFilePath: string

proc staticFile*(self: HttpContext, path: string = ""): string {.discardable.} =
  if path != "":
    self.staticFilePath = path

  return self.staticFilePath

proc newHttpContext*(self: zfblast.HttpContext): HttpContext {.gcsafe.} =
  #
  # create new HttpContext from the zfblast HttpContext
  #
  return HttpContext(
    client: self.client,
    request: self.request,
    response: self.response,
    send: self.send,
    keepAliveMax: self.keepAliveMax,
    keepAliveTimeout: self.keepAliveTimeout,
    webSocket: self.webSocket,
    params: initTable[string, string](),
    reParams: initTable[string, seq[string]](),
    formData: newFormData(),
    json: newJObject(),
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
  # if self.getCookies().hasKey("username"):
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
  # let cookies = self.getCookies
  # self.clearCookie(cookies)
  #
  self.setCookie(cookies, expires = "Thu, 01 Jan 1970 00:00:00 GMT")

proc getContentRange*(
  self: HttpContext,
  filePath: string = ""): tuple[content: string, headers: HttpHeaders, errMsg: ApiMsg] =
  #
  # get content range of file
  # will check request header from client if request contain Range: bytes=<start>-<stop>
  # then return requested data with length of the requested file
  # this method will defend then web server from overload of large request process
  #
  if filePath != "":
    self.staticFile(filePath)

  # handle range request
  let apiMsg = newApiMsg(success = false)
  result = ("", newHttpHeaders(), apiMsg)
  if self.staticFile().existsFile:
    let staticFile = self.staticFile.open
    let rangeHead = self.request.headers.getHttpHeaderValues("Range")
    var httpHeaders = newHttpHeaders()
    let rangeParams = rangeHead.split("=")
    if rangeParams.len == 2 and rangeParams[0].toLower().strip == "bytes":
      let rangeToRetrieves = rangeParams[1].split(",")
      # single request
      if rangeToRetrieves.len == 1:
        let rangePos = rangeToRetrieves[0].split("-")
        if rangePos.len == 2:
          let rangeStart = rangePos[0].strip().tryParseBiggestInt
          let rangeEnd = rangePos[1].strip().tryParseBiggestInt
          if rangeEnd.ok and rangeStart.ok and rangeEnd.val > rangeStart.val:
            let rangeLen = rangeEnd.val - rangeStart.val
            if rangeLen <= self.settings.responseRangeBuffer:
              staticFile.setFilePos(rangeStart.val)
              var charBuffer = rangeLen.newString
              discard staticFile.readChars(charBuffer, 0, charBuffer.len - 1)
              httpHeaders["Content-Range"] = &"bytes {rangeStart}-{rangeEnd}/{staticFile.getFileSize}"
              httpheaders["Max-Range"] = $self.settings.responseRangebuffer
              apiMsg.success = true
              result = (charBuffer, httpHeaders, apiMsg)
            else:
              apiMsg.error["msg"] = %"range not valid, max range {rangeLen} bytes."
          else:
            apiMsg.error["msg"] = %"invalid range value."
        else:
          apiMsg.error["msg"] = %"range definition invalid."
      else:
        apiMsg.error["msg"] = %"multipart range is not supported."
    else:
      apiMsg.error["msg"] = %"range header value invalid, only accept bytes."
    # close flie
    staticFile.close
  else:
    apiMsg.error["msg"] = % &"failed retrieve file."

proc gzCompress*(self: HttpContext, source: string): tuple[content: string, size: int] =
  let filename = self.settings.tmpGzipDir.joinPath(now().utc().format("yyyy-MM-dd HH:mm:ss:fffffffff").encode) & ".gz"
  let w = filename.newGzFileStream(fmWrite)
  let chunk_size = 32
  var num_bytes = source.len
  var idx = 0
  while true:
    w.writeData(source[idx].unsafeAddr, min(num_bytes, chunk_size))
    if num_bytes < chunk_size:
      break
    dec(num_bytes, chunk_size)
    inc(idx, min(num_bytes, chunk_size))
  w.close()
  let r = filename.newFileStream
  let data = r.readAll
  r.close
  result = (data, data.len)
  removeFile(filename)

proc gzDeCompress*(self: HttpContext, source: string): tuple[content: string, size: int] =
  let filename = self.settings.tmpGzipDir.joinPath(now().utc().format("yyyy-MM-dd HH:mm:ss:fffffffff").encode) & ".gz"
  let w = filename.newFileStream(fmWrite)
  w.write(source)
  w.close
  let r = filename.newGzFileStream
  let data = r.readAll
  r.close
  result = (data, data.len)
  removeFile(filename)

proc mapContentype*(self: HttpContext) =
  # HttpPost, HttpPut, HttpPatch will auto parse and extract the request, including the uploaded files
  # uploaded files will save to tmp folder

  # if content encoding is gzip format
  # decompress it first
  if self.request.headers.getHttpHeaderValues("Content-Encoding") == "gzip":
    let gzContent = self.gzDecompress(self.request.body)
    self.request.body = gzContent.content
    self.request.headers["Content-Length"] = $gzContent.size
  
  let contentType = self.request.headers.getHttpHeaderValues("Content-Type").toLower
  if self.request.httpMethod in [HttpPost, HttpPut, HttpPatch]:
    if contentType.find("multipart/form-data") != -1:
      self.formData = newFormData().parse(
        self.request.body,
        self.settings)

    if contentType.find("application/x-www-form-urlencoded") != -1:
      var query = initTable[string, string]()
      var uriToParse = self.request.body
      if self.request.body.find("?") == -1: uriToParse = &"?{uriToParse}"
      for q in uriToParse.parseUri3().getAllQueries():
        query.add(q[0], q[1].decodeUri())

      self.params = query

    if contentType.find("application/json") != -1:
      self.json = parseJson(self.request.body)

    # not need to keep the body after processing
    self.request.body = ""

proc isSupportGz*(self: HttpContext, contentType: string): bool =
  # prepare gzip support
  let accept =
    self.request.headers.getHttpHeaderValues("accept-encoding").toLower
  let typeToZip = contentType.toLower
  return (accept.startsWith("gzip") or accept.contains("gzip")) and
    (typeToZip.startsWith("text/") or typeToZip.startsWith("message/") or
    typeToZip in ["application/json", "application/xml", "application/xhtml",
    "application/xhtml+xml", "application/ld+json"])

proc toGzResp(self: HttpContext): Future[void] {.async.} =
  let contentType = self.response.headers.getHttpHeaderValues("Content-Type")
  if contentType == "":
    self.response.headers["Content-Type"] = "application/octet-stream"

  if self.request.httpMethod == HttpHead:
    if self.request.headers.getHttpHeaderValues("Accept-Ranges") == "":
      self.response.headers["Accept-Ranges"] = "bytes"
    if self.request.headers.getHttpHeaderValues("Accept-Encoding") == "":
      self.response.headers["Accept-Encoding"] = "gzip"

  if self.isSupportGz(contentType):
    let gzContent = self.gzCompress(self.response.body)
    if self.request.httpMethod != HttpHead:
      self.response.headers["Content-Encoding"] = "gzip"
      self.response.body = gzContent.content
    else:
      # gzip content should not allow ranges
      self.response.headers.del("Accept-Ranges")
      if self.response.body != "":
        self.response.headers["Content-Length"] = $gzContent.size
      # remove the body
      # head request doesn,t need the body
      self.response.body = ""

  elif self.request.httpMethod == HttpHead:
    # if not gzip support
    # and the request is HttpHead
    self.response.headers["Content-Length"] = $self.response.body.len
    self.response.body = ""

  await self.send(self)

proc resp*(
  self: HttpContext,
  httpCode: HttpCode,
  body: string,
  headers: HttpHeaders = nil) =
  #
  # response to the client
  # self.resp(Http200, "ok")
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

  asyncCheck self.toGzResp

proc resp*(
  self: HttpContext,
  httpCode: HttpCode,
  body: JsonNode,
  headers: HttpHeaders = nil) =
  #
  # response as application/json to the client
  # let msg = %*{"status": true}
  # self.resp(Http200, msg)
  #
  self.response.httpCode = httpCode
  self.response.headers["Content-Type"] = @["application/json"]
  self.response.body = $body
  if not headers.isNil:
    for k, v in headers.pairs:
      self.response.headers[k] = v

  asyncCheck self.toGzResp

proc respHtml*(
  self: HttpContext,
  httpCode: HttpCode,
  body: string,
  headers: HttpHeaders = nil) =
  #
  # response as html to the client
  # self.respHtml(Http200, """<html><body>Nice...</body></html>""")
  #
  self.response.httpCode = httpCode
  self.response.headers["Content-Type"] = @["text/html", "charset=utf-8"]
  self.response.body = $body
  if not headers.isNil:
    for k, v in headers.pairs:
      self.response.headers[k] = v

  asyncCheck self.toGzResp

proc respRedirect*(
  self: HttpContext,
  redirectTo: string) =
  #
  # response redirect to the client
  # self.respRedirect("https://google.com")
  #
  self.response.httpCode = Http303
  self.response.headers["Location"] = @[redirectTo]
  asyncCheck self.toGzResp

