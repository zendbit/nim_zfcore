#[
  zfcore web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#

import json, httpcore
export json, httpcore

type
  ApiMsg* = ref object
    status*: HttpCode
    success*: bool
    error*: JsonNode
    data*: JsonNode

proc `%`*(self: ApiMsg): JsonNode =
  result = %*{}
  result["status"] = % $self.status
  result["success"] = %self.success
  result["error"] = self.error
  result["data"] = self.data

proc newApiMsg*(
  success: bool = false,
  status: HttpCode = Http406,
  error: JsonNode = %*{},
  data: JsonNode = %*{}): ApiMsg =
  result = ApiMsg(
    status: status,
    success: success,
    error: error,
    data: data)
