#[
  ZendFlow web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#

#[
  This is middleware for filltering or for injecting action before route or after route
  after route will excute before actual route.

  this is usefull when we want to use for filtering or authentication before rouing happend,
  for example we want to validate header authorization we can do in the before routing middleware

  let zf = newZendFlow()

  zf.r.beforeRoute(proc (ctx: CtxReq): Future[void] {.async.} =

    #### your code here
    #### you can directly by pass respon from here before routing happend

    )
  zf.r.afterRoute(proc (ctx: CtxReq, route: Route): Future[void] {.async.} =

    #### your code here
    #### you can directly by pass respon from here after routing match happend
    #### and will call before the actual routing procedure called

    )

  zf.r.get("/home/<ids:re[([0-9]+)_([0-9]+)]:len[2]>/<body>", proc (
    ctx: CtxReq): Future[void] {.async.} =
    echo "Welcome home"
    echo $ctx.reParams["ids"]
    echo $ctx.params["body"]
    await ctx.resp(Http200, "Hello World"))

  zf.r.post("/home", proc (ctx: CtxReq): Future[void] {.async.} =
    await ctx.resp(Http200, "Hello World"))

  zf.serve()
]#
import
  route,
  asyncdispatch

from httpCtx import HttpCtx

type
  Middleware* = ref object of RootObj
    pre: proc (ctx: HttpCtx): Future[bool]
    post: proc (ctx: HttpCtx, route: Route): Future[bool]

proc newMiddleware*(): Middleware =
  return Middleware()

proc beforeRoute*(
  self: Middleware,
  pre: proc (ctx: HttpCtx): Future[bool]) =

  self.pre = pre

proc afterRoute*(
  self: Middleware,
  post: proc (ctx: HttpCtx, route: Route): Future[bool]) =

  self.post = post

proc execBeforeRoute*(
  self: Middleware, ctx: HttpCtx): Future[bool] {.async.} =

  if not isNil(self.pre):
    return await self.pre(ctx)

proc execAfterRoute*(
  self: Middleware,
  ctx: HttpCtx,
  route: Route): Future[bool] {.async.} =

  if not isNil(self.post):
    return await self.post(ctx, route)
