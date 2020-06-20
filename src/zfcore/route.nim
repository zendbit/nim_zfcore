#[
  ZendFlow web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#

# std
from asynchttpserver import HttpMethod
from asyncdispatch import Future

# local
from httpCtx import HttpCtx

type
  Route* = ref object
    httpMethod*: HttpMethod
    path*: string
    thenDo*: proc (ctx: HttpCtx): Future[void]
    segments*: seq[string]
