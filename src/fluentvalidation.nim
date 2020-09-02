#[
  zfcore web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#

#[
  Fluent validation for make easy to validate value
  let validation = newFluentValidation()
  validation
    .add(newFieldData("username", ctx.params["username"])
      .must("Username is required.")
      .reMatch("([\w\W]+@[\w\W]+\.[\w])$", "Email format is not valid."))
    .add(newFieldData("password", ctx.params["password"])
      .must("Password is required.")
      .rangeLen(10, 255, "Min password length is 10, max is 255."))
]#

import strutils, strformat, nre, parseutils, json, macros
export strutils, strformat, nre, parseutils, json
import stdext/[strutils_ext]

#[
  FieldData is object model of field to be validated
  name is field name
  value is the value of the field
  msg is valued when the validation contain an error
]#
type
  FieldData* = ref object
    name: string
    value: string
    discardValue: string
    msg: string
    isValid: bool
    validationApplied: string

const discardFlag = "####discard####"

proc newFieldData*(
  name: string,
  value: string): FieldData {.discardable.} =
  # create new field data for validation
  return FieldData(
    name: name.strip(),
    value: value.strip(),
    discardValue: discardFlag)

proc must*(
  self: FieldData,
  errMsg: string = "",
  okMsg:string = ""): FieldData =
  # set value as required
  # if value empty string
  # errMsg for error msg
  # okMsg for success msg
  if self.msg == "":
    self.validationApplied &= "|must"
    self.isValid = false
    if self.value == "":
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg =  "Value is required."

    else:
      self.isValid = true
      self.msg = okMsg

  return self

proc num*(
  self: FieldData,
  errMsg: string = "",
  okMsg:string = ""): FieldData {.discardable.} =
  # validate the value treat as number
  # if value not number will not valid
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.validationApplied &= "|num"
    self.isValid = self.value.tryParseBiggestUInt().ok and self.value != ""
    if self.isValid:
      self.msg = okMsg

    else:
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg = "Value is not valid number."

  return self

proc discardIf*(
  self: FieldData,
  discardValue: string): FieldData {.discardable.} =
  # validate the value treat as number
  # if value not number will not valid
  # errMsg for error msg
  # okMsg for success msg
  self.discardValue = discardValue
  return self

proc dec*(
  self: FieldData,
  errMsg: string = "",
  okMsg:string = ""): FieldData {.discardable.} =
  # validate the value treat as decimal
  # if value not number will not valid
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.validationApplied &= "|dec"
    self.isValid = self.value.tryParseBiggestFloat().ok and self.value != ""
    if self.isValid:
      self.msg = okMsg

    else:
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg = "Value is not valid number."

  return self

proc bool*(
  self: FieldData,
  errMsg: string = "",
  okMsg:string = ""): FieldData {.discardable.} =
  # validate the value treat as number
  # if value not number will not valid
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.validationApplied &= "|bool"
    self.isValid = self.value.tryParseBool().ok
    if self.isValid:
      self.msg = okMsg

    else:
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg = "Value is not valid number."

  return self

proc rangeNum*(
  self: FieldData,
  min: BiggestUInt,
  max: BiggestUint,
  errMsg: string = "",
  okMsg:string = ""): FieldData {.discardable.} =
  # validate the value in the range of given min and max
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.validationApplied &= "|rangeNum"
    var err = ""
    let (ok, val) = self.value.tryParseBiggestUInt()
    self.isValid = false
    if ok and self.value != "":
      if val < min or val > max:
        if errMsg != "":
            err = errMsg
        else:
            err = &"Value is not in range. ({min}-{max})"

      else:
        self.isValid = true
        self.msg = okMsg

    else:
      err = &"Value is not in range. ({min}-{max})"

    if err != "":
      self.msg = err

  return self

proc rangeDec*(
  self: FieldData,
  min: BiggestFloat,
  max: BiggestFloat,
  errMsg: string = "",
  okMsg:string = ""): FieldData {.discardable.} =
  # validate the value in the range of given min and max
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.validationApplied &= "|rangeDec"
    var err = ""
    let (ok, val) = self.value.tryParseBiggestFloat()
    self.isValid = false
    if ok and self.value != "":
      if val < min or val > max:
        if errMsg != "":
            err = errMsg
        else:
            err = &"Value is not in range. ({min}-{max})"

      else:
        self.isValid = true
        self.msg = okMsg

    else:
      err = &"Value is not in range. ({min}-{max})"

    if err != "":
      self.msg = err

  return self

proc maxNum*(
  self: FieldData,
  max: BiggestUInt,
  errMsg: string = "",
  okMsg:string = ""): FieldData {.discardable.} =
  # validate value must not larger than given max value
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.validationApplied &= "|maxNum"
    self.isValid = false
    var err = ""
    var (ok, val) = self.value.tryParseBiggestUInt()
    if ok and self.value != "":
      if val > max:
        if errMsg != "":
          err = errMsg
        else:
          err = &"Larger value not allowed. (>{max})"

      else:
        self.isValid = true
        self.msg = okMsg

    else:
      err = &"Larger value not allowed. (>{max})"

    if err != "":
      self.msg = err

  return self

proc maxDec*(
  self: FieldData,
  max: BiggestFloat,
  errMsg: string = "",
  okMsg:string = ""): FieldData {.discardable.} =
  # validate value must not larger than given max value
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.validationApplied &= "|maxDec"
    self.isValid = false
    var err = ""
    var (ok, val) = self.value.tryParseBiggestFloat()
    if ok and self.value != "":
      if val > max:
        if errMsg != "":
          err = errMsg
        else:
          err = &"Larger value not allowed. (>{max})"

      else:
        self.isValid = true
        self.msg = okMsg

    else:
      err = &"Larger value not allowed. (>{max})"

    if err != "":
      self.msg = err

  return self

proc minNum*(
  self: FieldData,
  min: BiggestUInt,
  errMsg: string = "",
  okMsg:string = ""): FieldData {.discardable.} =
  # validate value must not less than given min value
  # errMsg for error msg
  # okMsg for success msg
  if self.msg == "":
    self.validationApplied &= "|minNum"
    self.isValid = false
    var err = ""
    let (ok, val) = self.value.tryParseBiggestUInt()
    if ok and self.value != "":
      if val < min:
        if errMsg != "":
          err = errMsg
        else:
          err = &"Lower value not allowed. (<{min})"

      else:
        self.isValid = true
        self.msg = okMsg

    else:
      err = &"Lower value not allowed. (<{min})"

    if err != "":
      self.msg = err

  return self

proc minDec*(
  self: FieldData,
  min: BiggestFloat,
  errMsg: string = "",
  okMsg:string = ""): FieldData {.discardable.} =
  # validate value must not less than given min value
  # errMsg for error msg
  # okMsg for success msg
  if self.msg == "":
    self.validationApplied &= "|minDec"
    self.isValid = false
    var err = ""
    let (ok, val) = self.value.tryParseBiggestFloat()
    if ok and self.value != "":
      if val < min:
        if errMsg != "":
          err = errMsg
        else:
          err = &"Lower value not allowed. (<{min})"

      else:
        self.isValid = true
        self.msg = okMsg

    else:
      err = &"Lower value not allowed. (<{min})"

    if err != "":
      self.msg = err

  return self

proc customErr*(
  self: FieldData,
  errMsg: string = ""): FieldData =
  # create custom error message
  # errMsg for error msg
  self.msg =  errMsg
  self.isValid = false

  return self

proc customOk*(
  self: FieldData,
  okMsg: string = ""): FieldData =
  # create custom ok msg
  # okMsg for success msg 
  self.msg =  okMsg
  self.isValid = true

  return self

proc minLen*(
  self: FieldData,
  min: int,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =
  # validate the value length not less than the given min len
  # errMsg for error msg
  # okMsg for success msg
  if self.msg == "":
    self.validationApplied &= "|minLen"
    self.isValid = false
    if self.value.len < min:
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg = &"Lower value length not allowed. (<{min})"

    else:
      self.isValid = true
      self.msg = okMsg

  return self

proc maxLen*(
  self: FieldData,
  max: int,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =
  # validate the value length not larger than given max len
  # errMsg for error msg
  # okMsg for success msg
  if self.msg == "":
    self.validationApplied &= "|maxLen"
    self.isValid = false
    if self.value.len > max:
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg = &"Larger value length not allowed. (>{max})"

    else:
      self.isValid = true
      self.msg = okMsg
  return self

proc rangeLen*(
  self: FieldData,
  min: int,
  max: int,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =
  # validate the value length is in given range
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.validationApplied &= "|rangeLen"
    self.isValid = false
    if self.value.len > max or self.value.len < min:
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg = &"Value length not in range. ({min}-{max})"

    else:
      self.isValid = true
      self.msg = okMsg

  return self

proc reMatch*(
  self: FieldData,
  regex: string,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =
  # validate the value with given regex
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.validationApplied &= "|reMatch"
    self.isValid = false
    if not self.value.match(re(regex)).isSome:
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg = &"Value not match with pattern. ({regex})"

    else:
      self.isValid = true
      self.msg = okMsg

  return self

proc email*(
  self: FieldData,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =
  # validate the value is email format
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.validationApplied &= "|email"
    var localErrMsg = errMsg
    if localErrMsg != "":
      localErrMsg = "Email address format is not valid."

    self.reMatch(
      fmt"([\w\.\-]+@[\w\.\-]+\.[\w\.\-]+)$",
      localErrMsg,
      okMsg)

  return self

#[
  Fluent validation model
  this will handle and register FieldData model
  each data model will validate here
  valids field is contain HasTable of the valids fields
  notValids is for otherwise
]#
type
  FluentValidation* = ref object
    valids*: JsonNode
    notValids*: JsonNode

proc newFluentValidation*(): FluentValidation =
  # create new fluent validation
  var instance = FluentValidation()
  instance.valids = %*{}
  instance.notValids = %*{}
  return instance

proc `%`(self: FieldData): JsonNode =
  result = %*{
      "name": self.name,
      "msg": self.msg,
      "isValid": self.isValid,
      "value": self.value
    }

  if self.isValid:
    if self.validationApplied.toLower().contains("num") or
      self.validationApplied.toLower().contains("dec"):
      result["value"] = %self.value.tryParseBiggestUInt().val
    elif self.validationApplied.contains("bool"):
      result["value"] = %self.value.tryParseBool().val

proc validPairs*(self: FluentValidation): seq[tuple[k: string, v: string]] =
  # return valids validation result as seq kv pairs seq[k: string, v: string]
  var kv: seq[tuple[k: string, v: string]]
  for k, v in self.valids:
    kv.add((k, v{"value"}.getStr))
  return kv

proc notValidPairs*(self: FluentValidation): seq[tuple[k: string, v: string]] =
  # return not valids validation result as seq kv pairs seq[k: string, v: string]
  var kv: seq[tuple[k: string, v: string]]
  for k, v in self.notValids:
    kv.add((k, v{"value"}.getStr))
  return kv

proc add*(
  self: FluentValidation,
  fieldData: FieldData): FluentValidation {.discardable.} =
  # add field data validation to the fluent validation
  if fieldData.discardValue != fieldData.value:
    if not fieldData.isValid:
      self.notValids.add(fieldData.name, %fieldData)
    else:
      self.valids.add(fieldData.name, %fieldData)
  return self

proc clear*(self: FluentValidation) =
  # clear fluent validation
  self.valids = %*{}
  self.notValids = %*{}

proc isValid*(self: FluentValidation): bool =
  # check if validation success (valid all passes)
  return self.notValids.len == 0

###
### macros for the fluent validation
###
macro fluentValidation*(x: untyped): untyped =
  #
  # initialise fluent validation
  # make fluent validation more readable
  # let validation = fluentValidation:
  #   data "username" params.getOrDefault("username"):
  #     must:
  #       err "username is required."
  #     minLen 8:
  #       err "username must have min 8 chars."
  #     email:
  #       err "not valid email address."
  #   data "password" params.getOrDefault("password"):
  #     must:
  #       err "password is required."
  #     minLen 8:
  #       err "password must have min 8 chars."
  #
  var fv = nnkCall.newTree(newIdentNode("newFluentValidation"))
  let stmtList = newStmtList()
  for child in x.children:
    #
    # define child kind is data
    # get name and value parameter
    #
    let childKind = $child[0]
    case child.kind
    of nnkCommand:
      case childKind
      of "data":
        #
        # initialize field data for validation
        # then pass the name and value as params
        #
        let name = child[1][0]
        let value = child[1][1]
        let nameKind = name.kind
        let valueKind = value.kind 
        var fvData = nnkCall.newTree(
          newIdentNode("newFieldData"),
          name,
          value
        )
        
        for vChild in child[2]:
          let vChildKind = vChild.kind
          case vChildKind
          of nnkIdent:
            #
            # this validate
            # must
            # num
            #
            case $vChild
            of "bool", "must", "num", "email":
              fvData = nnkCall.newTree(
                nnkDotExpr.newTree(
                  fvData,
                  newIdentNode($vChild)
                )
              )

          of nnkCall:
            #
            # this validate
            # must:
            #   ok ""
            #   err ""
            #
            # num:
            #   ok ""
            #   err ""
            #
            let vChildKind = $vChild[0]
            case vChildKind
            of "bool", "must", "num", "email":
              var ok = ""
              var err = ""
              for msg in vChild[1]:
                case $msg[0]
                of "ok":
                  if not msg[1].isNil:
                    ok = msg[1].strVal
                of "err":
                  if not msg[1].isNil:
                    err = msg[1].strVal

              fvData = nnkCall.newTree(
                nnkDotExpr.newTree(
                  fvData,
                  newIdentNode(vChildKind)
                ),
                err.newLit,
                ok.newLit
              )

          of nnkCommand:
            #
            # this will validate
            # reMatch "":
            #   ok ""
            #   err ""
            #
            # rangeLen 2 255:
            #   ok ""
            #   err ""
            #
            # etc
            #
            let vChildKind = $vChild[0]
            case vChildKind
            of "rangeLen", "rangeNum":
              case vChild[1].kind
              of nnkCommand:
                let minLen = vChild[1][0]
                let maxLen = vChild[1][1]
                var ok = ""
                var err = ""
                if vChild.len >= 3:
                  for msg in vChild[2]:
                    case $msg[0]
                    of "ok":
                      if not msg[1].isNil:
                        ok = msg[1].strVal
                    of "err":
                      if not msg[1].isNil:
                        err = msg[1].strVal
              
                fvData = nnkCall.newTree(
                  nnkDotExpr.newTree(
                    fvData,
                    newIdentNode(vChildKind)
                  ),
                  minLen,
                  maxLen,
                  err.newLit,
                  ok.newLit
                )

              else:
                discard
            
            of "minLen", "maxLen", "maxNum", "minNum",
              "discardIf", "reMatch", "customErr", "customOk":
              case vChild[1].kind
              of nnkIntLit, nnkStrLit:
                let val = vChild[1]
                fvData = nnkCall.newTree(
                  nnkDotExpr.newTree(
                    fvData,
                    newIdentNode(vChildKind)
                  ),
                  val
                )

              of nnkCommand:
                let val = vChild[1][0]
                var ok = ""
                var err = ""
                if vChild.len >= 3:
                  for msg in vChild[2]:
                    case $msg[0]
                    of "ok":
                      if not msg[1].isNil:
                        ok = msg[1].strVal
                    of "err":
                      if not msg[1].isNil:
                        err = msg[1].strVal
                
                fvData = nnkCall.newTree(
                  nnkDotExpr.newTree(
                    fvData,
                    newIdentNode(vChildKind)
                  ),
                  val,
                  err.newLit,
                  ok.newLit
                )

              else:
                discard
             
            else:
              discard

          else:
            discard

        #
        # data
        #
        fv = nnkCall.newTree(
          nnkDotExpr.newTree(
            fv,
            newIdentNode("add")
          ),
          fvData
        )

    else:
      discard

  result = stmtList.add(fv)
