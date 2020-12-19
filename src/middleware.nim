#[
  zfcore web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#

# local
import route, httpcontext, asyncdispatch
export route, httpcontext, asyncdispatch

type
  PreRoute* = proc (ctx: HttpContext): Future[bool] {.gcsafe async.}
  PostRoute* = proc (ctx: HttpContext, route: Route): Future[bool] {.gcsafe async.}
  Middleware* = ref object of RootObj
    #
    # Middleware
    # pre is callback for prerouting
    # post is callback for postrouting
    #
    pre: seq[PreRoute]
    post: seq[PostRoute]

proc newMiddleware*(): Middleware {.gcsafe.} =
  #
  # create new middleware
  #
  return Middleware()

proc addBeforeRoute*(
  self: Middleware,
  pre: PreRoute) {.gcsafe.} =
  #
  # add before route in middleware
  # this will always check on client request before routing process
  #
  self.pre.add(pre)

proc addAfterRoute*(
  self: Middleware,
  post: PostRoute) {.gcsafe.} =
  #
  # add after route in middleware
  # this will always check on client request after routing process
  #
  self.post.add(post)

proc beforeRoutes*(self: Middleware): seq[PreRoute] =
  return self.pre

proc afterRoutes*(self: Middleware): seq[PostRoute] =
  return self.post

#proc execBeforeRoute*(
#  self: Middleware, ctx: HttpContext): bool {.gcsafe.} =
  #
  # execute the before routing callback check
  #
#  if not self.pre.isNil:
#    return self.pre(ctx)

#proc execAfterRoute*(
#  self: Middleware,
#  ctx: HttpContext,
#  route: Route): bool {.gcsafe.} =
  #
  # execute the after routing callback check
  #
#  if not self.post.isNil:
#    return self.post(ctx, route)
