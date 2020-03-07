#[
    ZendFlow web framework for nim language
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

import
    strutils,
    strformat,
    re,
    tables

#[
    FieldData is object model of field to be validated
    name is field name
    value is the value of the field
    errorMsg is valued when the validation contain an error
]#
type
    FieldData* = ref object
        name: string
        value: string
        errorMsg: string

proc newFieldData*(name: string, value: string): FieldData {.discardable.} =
    return FieldData(name: name.strip(), value: value.strip())

proc must*(self: FieldData, errMsg: string = ""): FieldData =
    if self.value == "" and self.errorMsg == "":
        if errMsg != "":
            self.errorMsg = errMsg
        else:
            self.errorMsg =  "Value is required."

    return self

proc num*(self: FieldData, errMsg: string = ""): FieldData {.discardable.} =
    if self.errorMsg == "":
        try:
            discard parseFloat(self.value)

        except Exception:
            if errMsg != "":
                self.errorMsg = errMsg
            else:
                self.errorMsg = "Value is not valid number."

    return self

proc rangeNum*(self: FieldData, min: float64, max: float64,
        errMsg: string = ""): FieldData {.discardable.} =

    if self.errorMsg == "":
        var err = ""
        try:
            let num = parseFloat(self.value)
            if num < min or num > max:
                if errMsg != "":
                    err = errMsg
                else:
                    err = &"Value is not in range. ({min}-{max})"

        except Exception:
            err = &"Value is not in range. ({min}-{max})"

        if err != "":
            self.errorMsg = err

    return self

proc maxNum*(self: FieldData, max: float64, errMsg: string = ""):
        FieldData {.discardable.} =
    if self.errorMsg == "":
        var err = ""
        try:
            let num = parseFloat(self.value)
            if num > max:
                if errMsg != "":
                    err = errMsg
                else:
                    err = &"Larger value not allowed. (>{max})"

        except Exception:
            err = &"Larger value not allowed. (>{max})"

        if err != "":
            self.errorMsg = err

    return self

proc minNum*(self: FieldData, min: float64, errMsg: string = ""):
        FieldData {.discardable.} =
    if self.errorMsg == "":
        var err = ""
        try:
            let num = parseFloat(self.value)
            if num < min:
                if errMsg != "":
                    err = errMsg
                else:
                    err = &"Lower value not allowed. (<{min})"

        except Exception:
            err = &"Lower value not allowed. (<{min})"

        if err != "":
            self.errorMsg = err

    return self

proc minLen*(self: FieldData, min: int, errMsg: string = ""):
        FieldData {.discardable.} =
    if self.value.len < min and self.errorMsg == "":
        if errMsg != "":
            self.errorMsg = errMsg
        else:
            self.errorMsg = &"Lower value length not allowed. (<{min})"

    return self

proc maxLen*(self: FieldData, max: int, errMsg: string = ""):
        FieldData {.discardable.} =
    if self.value.len > max and self.errorMsg == "":
        if errMsg != "":
            self.errorMsg = errMsg
        else:
            self.errorMsg = &"Larger value length not allowed. (>{max})"

    return self

proc rangeLen*(self: FieldData, min: int, max: int, errMsg: string = ""):
        FieldData {.discardable.} =
    if (self.value.len > max or self.value.len < min) and self.errorMsg == "":
        if errMsg != "":
            self.errorMsg = errMsg
        else:
            self.errorMsg = &"Value length not in range. ({min}-{max})"

    return self

proc reMatch*(self: FieldData, regex: string, errMsg: string = ""):
        FieldData {.discardable.} =
    if not match(self.value, re regex) and self.errorMsg == "":
        if errMsg != "":
            self.errorMsg = errMsg
        else:
            self.errorMsg = &"Value not match with pattern. ({regex})"

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
    var instance = FluentValidation()
    instance.valids = initTable[string, FieldData]()
    instance.notValids = initTable[string, FieldData]()
    return instance

proc add*(self: FluentValidation, fieldData: FieldData):
        FluentValidation {.discardable.} =
    if fieldData.errorMsg.len != 0:
        self.notValids.add(fieldData.name, fieldData)
    else:
        self.valids.add(fieldData.name, fieldData)
    return self

#proc validate*(self: FluentValidation):
#        tuple[valids: Table[string, FieldData],
#            notValids: Table[string, FieldData]] =
#    return (valids: self.valids, notValids: self.notValids)
