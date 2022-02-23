##
##  zfcore web framework for nim language
##  This framework if free to use and to modify
##  License: BSD
##  Author: Amru Rosyada
##  Email: amru.rosyada@gmail.com
##  Git: https://github.com/zendbit/nim.zfcore
##

# local
import
  route,
  httpcontext,
  asyncdispatch

export
  Route,
  HttpContext,
  asyncdispatch

type
  PreRoute* = proc (ctx: HttpContext):
    Future[bool] {.gcsafe async.}
  PostRoute* = proc (ctx: HttpContext, route: Route):
    Future[bool] {.gcsafe async.}
  Middleware* = ref object of RootObj
    ##
    ##  Middleware type:
    ##
    ##  pre is callback for prerouting
    ##  post is callback for postrouting
    ##
    pre: seq[PreRoute]
    post: seq[PostRoute]

proc newMiddleware*(): Middleware {.gcsafe.} =
  ##
  ##  create new middleware
  ##
  result = Middleware()

proc addBeforeRoute*(
  self: Middleware,
  pre: PreRoute) {.gcsafe.} =
  ##
  ##  add action before route:
  ##
  ##  add before route in middleware
  ##  this will always check on client request before routing process
  ##
  self.pre.add(pre)

proc addAfterRoute*(
  self: Middleware,
  post: PostRoute) {.gcsafe.} =
  ##
  ##  add action after route:
  ##
  ##  add after route in middleware
  ##  this will always check on client request after routing process
  ##
  self.post.add(post)

proc beforeRoutes*(self: Middleware): seq[PreRoute] =
  ##
  ##  before route:
  ##
  ##  execute before route action.
  ##
  result = self.pre

proc afterRoutes*(self: Middleware): seq[PostRoute] =
  ##
  ##  after route:
  ##
  ##  execute after route action.
  ##
  result = self.post

