##
##  zfcore web framework for nim language
##  This framework if free to use and to modify
##  License: BSD
##  Author: Amru Rosyada
##  Email: amru.rosyada@gmail.com
##  Git: https://github.com/zendbit/nim.zfcore
##
import httpcore
export httpcore
import apimsg
export apimsg

type
  RespMsg* = ref object
    msg*: ApiMsg
    httpCode*: HttpCode

proc newRespMsg*(
  httpCode: HttpCode = Http406,
  success: bool = false,
  data: JsonNode = %*{},
  error: JsonNode = %*{}): RespMsg =
  return RespMsg(
    httpCode: httpCode,
    msg: newApiMsg(success=success, data=data, error=error))
