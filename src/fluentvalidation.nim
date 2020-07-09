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

import strutils, strformat, re, tables, parseutils
export strutils, strformat, re, tables, parseutils

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
    msg: string
    isValid: bool

proc newFieldData*(
  name: string,
  value: string): FieldData {.discardable.} =
  # create new field data for validation
  return FieldData(
    name: name.strip(),
    value: value.strip())

proc must*(
  self: FieldData,
  errMsg: string = "",
  okMsg:string = ""): FieldData =
  # set value as required
  # if value empty string
  # errMsg for error msg
  # okMsg for success msg
  if self.msg == "":
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
    self.isValid = false
    var res: float64
    self.isValid = self.value.strip.parseBiggestFloat(res, 0) == self.value.strip.len
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
  min: float64,
  max: float64,
  errMsg: string = "",
  okMsg:string = ""): FieldData {.discardable.} =
  # validate the value in the range of given min and max
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    var err = ""
    self.isValid = false
    var num: float64
    if self.value.strip.parseBiggestFloat(num, 0) == self.value.strip.len:
      if num < min or num > max:
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
  max: float64,
  errMsg: string = "",
  okMsg:string = ""): FieldData {.discardable.} =
  # validate value must not larger than given max value
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.isValid = false
    var err = ""
    var num: float64
    if self.value.strip.parseBiggestFloat(num, 0) == self.value.strip.len:
      if num > max:
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
  min: float64,
  errMsg: string = "",
  okMsg:string = ""): FieldData {.discardable.} =
  # validate value must not less than given min value
  # errMsg for error msg
  # okMsg for success msg 
  if self.msg == "":
    self.isValid = false
    var err = ""
    var num: float64
    if self.value.strip.parseBiggestFloat(num, 0) == self.value.strip.len:
      if num < min:
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
    self.isValid = false
    if (self.value.len > max or self.value.len < min):
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
    self.isValid = false
    if not self.value.match(re regex):
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
    valids*: Table[string, FieldData]
    notValids*: Table[string, FieldData]

proc newFluentValidation*(): FluentValidation =
  # create new fluent validation
  var instance = FluentValidation()
  instance.valids = initTable[string, FieldData]()
  instance.notValids = initTable[string, FieldData]()
  return instance

proc add*(
  self: FluentValidation,
  fieldData: FieldData): FluentValidation {.discardable.} =
  # add field data validation to the fluent validation
  if not fieldData.isValid:
    self.notValids.add(fieldData.name, fieldData)
  else:
    self.valids.add(fieldData.name, fieldData)
  return self

proc clear*(self: FluentValidation) =
  # clear fluent validation
  clear(self.valids)
  clear(self.notValids)

proc isValid*(self: FluentValidation): bool =
  # check if validation success (valid all passes)
  return self.notValids.len == 0
