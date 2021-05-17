##
##  zfcore web framework for nim language
##  This framework if free to use and to modify
##  License: BSD
##  Author: Amru Rosyada
##  Email: amru.rosyada@gmail.com
##  Git: https://github.com/zendbit/nim.zfcore
##

import json, httpcore
export json, httpcore

type
  RespMsg* = ref object
    ##
    ## api msg type:
    ##
    ## Api message type for standard json output.
    ##
    status*: HttpCode
    success*: bool
    error*: JsonNode
    data*: JsonNode

proc `%`*(self: RespMsg): JsonNode =
  ##
  ##  api msg to JsonNode:
  ##
  ##  convert api msg type to JsonNode.
  ##
  result = %*{}
  result["status"] = % $self.status
  result["success"] = %self.success
  result["error"] = self.error
  result["data"] = self.data

proc newRespMsg*(
  success: bool = false,
  status: HttpCode = Http406,
  error: JsonNode = %*{},
  data: JsonNode = %*{}): ApiMsg =
  ##
  ##  new api msg:
  ##
  ##  create new api msg type.
  ##
  result = RespMsg(
    status: status,
    success: success,
    error: error,
    data: data)
