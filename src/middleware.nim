#[
  zfcore web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#

# local
import route, httpcontext
export route, httpcontext

type
  Middleware* = ref object of RootObj
    #
    # Middleware
    # pre is callback for prerouting
    # post is callback for postrouting
    #
    pre: proc (ctx: HttpContext): bool {.gcsafe.}
    post: proc (ctx: HttpContext, route: Route): bool {.gcsafe.}

proc newMiddleware*(): Middleware {.gcsafe.} =
  #
  # create new middleware
  #
  return Middleware()

proc beforeRoute*(
  self: Middleware,
  pre: proc (ctx: HttpContext): bool {.gcsafe.}) {.gcsafe.} =
  #
  # add before route in middleware
  # this will always check on client request before routing process
  #
  self.pre = pre

proc afterRoute*(
  self: Middleware,
  post: proc (ctx: HttpContext, route: Route): bool {.gcsafe.}) {.gcsafe.} =
  #
  # add after route in middleware
  # this will always check on client request after routing process
  #
  self.post = post

proc execBeforeRoute*(
  self: Middleware, ctx: HttpContext): bool {.gcsafe.} =
  #
  # execute the before routing callback check
  #
  if not self.pre.isNil:
    return self.pre(ctx)

proc execAfterRoute*(
  self: Middleware,
  ctx: HttpContext,
  route: Route): bool {.gcsafe.} =
  #
  # execute the after routing callback check
  #
  if not self.post.isNil:
    return self.post(ctx, route)
