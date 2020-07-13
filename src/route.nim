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
import asyncdispatch

# local
from httpcontext import HttpContext

type
  Route* = ref object
    #
    # Route object
    #
    httpMethod*: HttpMethod
    path*: string
    thenDo*: proc (ctx: HttpContext): Future[void] {.gcsafe async.}
    segments*: seq[string]
