##
##  zfcore web framework for nim language
##  This framework if free to use and to modify
##  License: BSD
##  Author: Amru Rosyada
##  Email: amru.rosyada@gmail.com
##  Git: https://github.com/zendbit/nim.zfcore
##

##  Fluent validation for make easy to validate value
##  let validation = newFluentValidation()
##  validation
##    .add(newFieldData("username", ctx.params["username"])
##      .must("Username is required.")
##      .reMatch("([\w\W]+@[\w\W]+\.[\w])$", "Email format is not valid."))
##    .add(newFieldData("password", ctx.params["password"])
##      .must("Password is required.")
##      .rangeLen(10, 255, "Min password length is 10, max is 255."))
##

## std import
import
  strutils,
  strformat,
  regex,
  parseutils,
  json,
  macros,
  times,
  options

export
  strutils,
  strformat,
  regex,
  parseutils,
  json,
  options

##  import stdext
import stdext/xstrutils

##
##  FieldData is object model of field to be validated
##  name is field name
##  value is the value of the field
##  msg is valued when the validation contain an error
##

type
  FieldData* = ref object of RootObj
    name: string
    value: string
    discardValues: seq[string]
    msg: string
    isValid: bool
    validationApplied: string

proc newFieldData*(
  name: string,
  value: string): FieldData {.discardable.} =

  # create new field data for validation
  return FieldData(
    name: name.strip(),
    value: value.strip(),
    discardValues: @[])

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
        self.msg =  "required."

    else:
      self.isValid = true
      self.msg = okMsg

  result = self

proc datetime*(
  self: FieldData,
  format: string,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =

  # validate the value treat as datetime format
  # if value not datetime format will not valid
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.validationApplied &= "|datetime"
    self.isValid = false
    try:
      discard self.value.parse(format)
      self.isValid = not self.isValid
      self.msg = okMsg

    except:
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg = "not valid datetime format."

  result = self

proc num*(
  self: FieldData,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =

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
        self.msg = "not valid number."

  result = self

proc discardVal*(
  self: FieldData,
  discardValue: string,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =

  # validate the value treat as number
  # if value not number will not valid
  # errMsg for error msg
  # okMsg for success msg
  self.discardValues.add(discardValue)
  result = self

proc discardVal*(
  self: FieldData,
  discardValues: seq[string],
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =

  # validate the value treat as number
  # if value not number will not valid
  # errMsg for error msg
  # okMsg for success msg
  self.discardValues = discardValues
  result = self

proc dec*(
  self: FieldData,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =

  # validate the value treat as decimal
  # if value not number will not valid
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.validationApplied &= "|dec"
    self.isValid = self.value
      .tryParseBiggestFloat().ok and self.value != ""
    if self.isValid:
      self.msg = okMsg

    else:
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg = "not valid decimal number."

  result = self

proc boolean*(
  self: FieldData,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =

  # validate the value treat as number
  # if value not number will not valid
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.validationApplied &= "|bool"
    self.isValid = self.value
      .tryParseBool().ok
    if self.isValid:
      self.msg = okMsg

    else:
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg = "not valid boolean."

  result = self

proc list*[T](
  self: FieldData,
  list: openArray[T],
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =

  # validate the value in the range of given min and max
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    var ok: bool
    var val: T
    var validationType = "listNum"

    when T is openArray[string]:
      validationType = "|listStr"
      val = self.value
      ok = true
    elif T is openArray[BiggestUInt] or
      T is openArray[uint64]:
      let res = self.value.tryParseBiggestUInt()
      ok = res.ok
      val = res.val
    elif T is openArray[BiggestInt] or
      T is openArray[int64]:
      let res = self.value.tryParseBiggestInt()
      ok = res.ok
      val = res.val
    elif T is openArray[int]:
      let res = self.value.tryParseInt()
      ok = res.ok
      val = res.val
    elif T is openArray[uint]:
      let res = self.value.tryParseUInt()
      ok = res.ok
      val = res.val
    elif T is openArray[float]:
      let res = self.value.tryParseBiggestFloat()
      ok = res.ok
      val = res.val
    elif T is openArray[float32]:
      let res = self.value.tryParseFloat()
      ok = res.ok
      val = res.val
    elif T is openArray[enum]:
      let res = self.value.tryParseEnum()
      ok = res.ok
      val = res.val

    var err = ""
    self.isValid = false
    self.validationApplied &= validationType

    if val notin list:
      if errMsg != "":
          err = errMsg
      else:
          err = &"not in {list}."

    else:
      self.isValid = true
      self.msg = okMsg

    if err != "":
      self.msg = err

  result = self

proc range*[T](
  self: FieldData,
  minValue: T,
  maxValue: T,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =

  # validate the value in the range of given min and max
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    var ok: bool
    var val: T

    when T is BiggestUInt or
      T is uint64:
      let res = self.value.tryParseBiggestUInt()
      ok = res.ok
      val = res.val
    elif T is BiggestInt or
      list is openArray[int64]:
      let res = self.value.tryParseBiggestInt()
      ok = res.ok
      val = res.val
    elif T is int:
      let res = self.value.tryParseInt()
      ok = res.ok
      val = res.val
    elif T is uint:
      let res = self.value.tryParseUInt()
      ok = res.ok
      val = res.val
    elif T is float:
      let res = self.value.tryParseBiggestFloat()
      ok = res.ok
      val = res.val
    elif T is float32:
      let res = self.value.tryParseFloat()
      ok = res.ok
      val = res.val

    self.validationApplied &= "|rangeNum"
    var err = ""

    self.isValid = false
    if ok and self.value != "":
      if val < minValue or val > maxValue:
        if errMsg != "":
            err = errMsg
        else:
            err = &"not in range ({minValue}-{maxValue})."

      else:
        self.isValid = true
        self.msg = okMsg

    else:
      err = &"not in range ({min}-{max})."

    if err != "":
      self.msg = err

  result = self

proc maxVal*[T](
  self: FieldData,
  value: T,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =

  # validate value must not larger than given max value
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    var ok: bool
    var val: T

    when T is BiggestUInt or
      T is uint64:
      let res = self.value.tryParseBiggestUInt()
      ok = res.ok
      val = res.val
    elif T is BiggestInt or
      T is int64:
      let res = self.value.tryParseBiggestInt()
      ok = res.ok
      val = res.val
    elif T is int:
      let res = self.value.tryParseInt()
      ok = res.ok
      val = res.val
    elif T is uint:
      let res = self.value.tryParseUInt()
      ok = res.ok
      val = res.val
    elif T is float:
      let res = self.value.tryParseBiggestFloat()
      ok = res.ok
      val = res.val
    elif T is float32:
      let res = self.value.tryParseFloat()
      ok = res.ok
      val = res.val

    self.validationApplied &= "|maxNum"
    self.isValid = false
    var err = ""

    if ok and self.value != "":
      if val > value:
        if errMsg != "":
          err = errMsg
        else:
          err = &"not allowed (>{value})."

      else:
        self.isValid = true
        self.msg = okMsg

    else:
      err = &"not allowed (>{value})."

    if err != "":
      self.msg = err

  result = self

proc minVal*[T](
  self: FieldData,
  value: T,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =

  # validate value must not less than given min value
  # errMsg for error msg
  # okMsg for success msg
  if self.msg == "":
    var ok: bool
    var val: T

    when T is BiggestUInt or
      T is uint64:
      let res = self.value.tryParseBiggestUInt()
      ok = res.ok
      val = res.val
    elif T is BiggestInt or
      T is int64:
      let res = self.value.tryParseBiggestInt()
      ok = res.ok
      val = res.val
    elif T is int:
      let res = self.value.tryParseInt()
      ok = res.ok
      val = res.val
    elif T is uint:
      let res = self.value.tryParseUInt()
      ok = res.ok
      val = res.val
    elif T is float:
      let res = self.value.tryParseBiggestFloat()
      ok = res.ok
      val = res.val
    elif T is float32:
      let res = self.value.tryParseFloat()
      ok = res.ok
      val = res.val

    self.validationApplied &= "|minNum"
    self.isValid = false
    var err = ""

    if ok and self.value != "":
      if val < value:
        if errMsg != "":
          err = errMsg
        else:
          err = &"not allowed (<{value})."

      else:
        self.isValid = true
        self.msg = okMsg

    else:
      err = &"not allowed (<{value})."

    if err != "":
      self.msg = err

  result = self

proc customErr*(
  self: FieldData,
  errMsg: string = ""): FieldData =

  # create custom error message
  # errMsg for error msg
  self.msg =  errMsg
  self.isValid = false

  result = self

proc customOk*(
  self: FieldData,
  okMsg: string = ""): FieldData =

  # create custom ok msg
  # okMsg for success msg 
  self.msg =  okMsg
  self.isValid = true

  result = self

proc minLen*(
  self: FieldData,
  value: int,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =

  # validate the value length not less than the given min len
  # errMsg for error msg
  # okMsg for success msg
  if self.msg == "":
    self.validationApplied &= "|minLen"
    self.isValid = false
    if self.value.len < value:
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg = &"not allowed (<{value})."

    else:
      self.isValid = true
      self.msg = okMsg

  result = self

proc maxLen*(
  self: FieldData,
  value: int,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =

  # validate the value length not larger than given max len
  # errMsg for error msg
  # okMsg for success msg
  if self.msg == "":
    self.validationApplied &= "|maxLen"
    self.isValid = false
    if self.value.len > value:
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg = &"not allowed (>{value})."

    else:
      self.isValid = true
      self.msg = okMsg
  result = self

proc rangeLen*(
  self: FieldData,
  minValue: int,
  maxValue: int,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =

  # validate the value length is in given range
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.validationApplied &= "|rangeLen"
    self.isValid = false
    if self.value.len > maxValue or self.value.len < minValue:
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg = &"not in range ({minValue}-{maxValue})."

    else:
      self.isValid = true
      self.msg = okMsg

  result = self

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
    if not self.value.match(re(regex)):
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg = &"not match with pattern ({regex})."

    else:
      self.isValid = true
      self.msg = okMsg

  result = self

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
    if localErrMsg == "":
      localErrMsg = "not valid email address."

    self.reMatch(
      fmt"([\w\.\-]+@[\w\.\-]+\.[\w\.\-]+)$",
      localErrMsg,
      okMsg)

  result = self

proc check*(
  self: FieldData,
  cond: proc (): bool,
  errMsg: string = "",
  okMsg: string = ""): FieldData {.discardable.} =

  # check condition if true or false
  # errMsg for error msg
  # okMsg for success msg
  if self.msg == "":
    self.validationApplied &= "|check"
    self.isValid = false
    var err = ""
    if not cond():
      if errMsg != "":
        self.msg = errMsg
      else:
        self.msg = &"invalid check condition."

    else:
      self.isValid = true
      self.msg = okMsg

  result = self

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

proc `&`*(self: FluentValidation, mergeWith: FluentValidation): FluentValidation =
  result = newFluentValidation()
  for k, v in self.valids:
    result.valids[k] = v

  for k, v in mergeWith.valids:
    result.valids[k] = v

  for k, v in self.notValids:
    result.notValids[k] = v

  for k, v in mergeWith.notValids:
    result.notValids[k] = v

template `&=`*(self: var FluentValidation, mergeWith: FluentValidation): untyped =
  for k, v in mergeWith.valids:
    self.valids[k] = v

  for k, v in mergeWith.notValids:
    self.notValids[k] = v

proc `%`(self: FieldData): JsonNode =

  result = %*{
      "name": self.name,
      "msg": self.msg,
      "isValid": self.isValid,
      "value": self.value
    }

  if self.isValid:
    if self.validationApplied.toLower().contains("num"):
      result["value"] = %self.value.tryParseBiggestUInt().val
    elif self.validationApplied.toLower().contains("dec"):
      result["value"] = %self.value.tryParseBiggestFloat().val
    elif self.validationApplied.contains("bool"):
      result["value"] = %self.value.tryParseBool().val

proc validPairs*(self: FluentValidation): JsonNode =

  # return valids validation result as JsonNode pairs key value
  result = %*{}
  for k, v in self.valids:
    result[k] = v{"value"}

proc notValidPairs*(self: FluentValidation): JsonNode =

  # return not valids validation result as JsonNode pairs key value
  result = %*{}
  for k, v in self.valids:
    result[k] = v{"value"}

proc add*(
  self: FluentValidation,
  fieldData: FieldData): FluentValidation {.discardable.} =

  # add field data validation to the fluent validation
  #if fieldData.discardValue != fieldData.value or
  #  (fieldData.value notin fieldData.discardValues):
  if fieldData.value notin fieldData.discardValues:
    if not fieldData.isValid:
      self.notValids.add(fieldData.name, %fieldData)
    else:
      self.valids.add(fieldData.name, %fieldData)
  result = self

proc clear*(self: FluentValidation) =

  # clear fluent validation
  self.valids = %*{}
  self.notValids = %*{}

proc isValid*(self: FluentValidation): bool =

  # check if validation success (valid all passes)
  result = self.notValids.len == 0

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
    if child.kind == nnkCommentStmt:
      stmtList.add(child)
      continue

    case child.kind
    of nnkCommand:
      let childKind = child[0].strVal
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
            case vChild.strVal
            of "bool", "must", "num", "email", "dec":
              fvData = nnkCall.newTree(
                nnkDotExpr.newTree(
                  fvData,
                  newIdentNode(vChild.strVal)
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
            let vChildKind = vChild[0].strVal
            case vChildKind
            of "bool", "must", "num", "email", "dec":
              var ok: NimNode = "".newLit
              var err: NimNode = "".newLit
              for msg in vChild[1]:
                case msg[0].strVal
                of "ok":
                  if not msg[1].isNil:
                    ok = msg[1]
                of "err":
                  if not msg[1].isNil:
                    err = msg[1]

              fvData = nnkCall.newTree(
                nnkDotExpr.newTree(
                  fvData,
                  newIdentNode(vChildKind)
                ),
                err,
                ok
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
            let vChildKind = vChild[0].strVal
            case vChildKind
            of "rangeLen", "range":
              let minLen = vChild[1][0]
              let maxLen = vChild[1][1]
              var ok: NimNode = "".newLit
              var err: NimNode = "".newLit
              case vChild[1].kind
              of nnkCommand:
                if vChild.len >= 3:
                  for msg in vChild[2]:
                    case msg[0].strVal
                    of "ok":
                      if not msg[1].isNil:
                        ok = msg[1]
                    of "err":
                      if not msg[1].isNil:
                        err = msg[1]
              else:
                discard

              fvData = nnkCall.newTree(
                nnkDotExpr.newTree(
                  fvData,
                  newIdentNode(vChildKind)
                ),
                minLen,
                maxLen,
                err,
                ok
              )
            
            of "minLen", "maxLen", "maxVal", "minVal", "list",
              "datetime", "discardVal", "reMatch", "customErr", "customOk", "check":
              let val = vChild[1]
              var ok: NimNode = "".newLit
              var err: NimNode = "".newLit
              case vChild.kind
              of nnkCommand:
                if vChild.len >= 3:
                  for msg in vChild[2]:
                    case msg[0].strVal
                    of "ok":
                      if not msg[1].isNil:
                        ok = msg[1]
                    of "err":
                      if not msg[1].isNil:
                        err = msg[1]
              else:
                discard

              fvData = nnkCall.newTree(
                nnkDotExpr.newTree(
                  fvData,
                  newIdentNode(vChildKind)
                ),
                val,
                err,
                ok
              )
            else:
              echo &"{vChildKind} not found in fluent validation."
              stmtList.add(vChild)
              

          else:
            stmtList.add(vChild)

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
      stmtList.add(child)

  result = stmtList.add(fv)
