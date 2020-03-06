#[
    ZendFlow web framework for nim language
    This framework if free to use and to modify
    License: BSD
    Author: Amru Rosyada
    Email: amru.rosyada@gmail.com
    Git: https://github.com/zendbit
]#

from asynchttpserver import HttpMethod
from asyncdispatch import Future
from ctxReq import CtxReq

type
    Route* = ref object
        httpMethod*: HttpMethod
        path*: string
        thenDo*: proc (ctx: CtxReq): Future[void] {.gcsafe.}
        segments*: seq[string]
