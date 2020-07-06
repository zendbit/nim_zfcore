#[
  zfcore web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#

import
  json

type
  ApiMsg* = ref object
    success: bool
    error: JsonNode
    data: JsonNode

proc `%`*(apiMsg: ApiMsg): JsonNode =
  result = %*{}
  result["success"] = %apiMsg.success
  result["error"] = apiMsg.error
  result["data"] = apiMsg.data

proc newApiMsg*(success: bool = false, error: JsonNode = %*{}, data: JsonNode = %*{}): ApiMsg =
  result = ApiMsg(success: success, error: error, data: data)
