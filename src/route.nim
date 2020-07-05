#[
  zfcore web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#

# std
from asynchttpserver import HttpMethod
from asyncdispatch import Future
import sugar

# local
from httpcontext import HttpContext

type
  Route* = ref object
    #
    # Route object
    #
    httpMethod*: HttpMethod
    path*: string
    thenDo*: (ctx: HttpContext) -> Future[void]
    segments*: seq[string]
