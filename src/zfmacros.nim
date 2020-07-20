#[
  zfcore web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#

# this is the macro to make the coding more easy using zfcore
# simpiify the construction of routing definition
# resp, setCookie etc
import macros, strutils, httpcore, strtabs
export macros
import zfcore
import httpcontext

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
    let childKind = ($child[0]).strip
    let name = ($child[1][0]).strip
    let value = ($child[1][1])
    case child.kind
    of nnkCommand:
      case childKind
      of "data":
        #
        # initialize field data for validation
        # za  hen pass the name and value as params
        #
        var fvData = nnkCall.newTree(
          newIdentNode("newFieldData"),
          newLit(name),
          newLit(value)
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
                  newIdentNode(($vChild).strip)
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
            let vChildKind = ($vChild[0]).strip
            case vChildKind
            of "bool", "must", "num", "email":
              var ok = ""
              var err = ""
              for msg in vChild[1]:
                case $msg[0]
                of "ok":
                  ok = $msg[1]
                of "err":
                  err = $msg[1]

              fvData = nnkCall.newTree(
                nnkDotExpr.newTree(
                  fvData,
                  newIdentNode(vChildKind)
                ),
                newLit(err),
                newLit(ok)
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
            let vChildKind = ($vChild[0]).strip
            case vChildKind
            of "reMatch":
              let reStr = $vChild[1]
              var ok = ""
              var err = ""
              if vChild.len >= 3:
                for msg in vChild[2]:
                  case $msg[0]
                  of "ok":
                    ok = $msg[1]
                  of "err":
                    err = $msg[1]
              
              fvData = nnkCall.newTree(
                nnkDotExpr.newTree(
                  fvData,
                  newIdentNode(vChildKind)
                ),
                newLit(reStr),
                newLit(err),
                newLit(ok)
              )
            
            of "customErr", "customOk":
              let msg = $vChild[1]
              fvData = nnkCall.newTree(
                nnkDotExpr.newTree(
                  fvData,
                  newIdentNode(vChildKind)
                ),
                newLit(msg)
              )

            of "rangeLen":
              let vChildRangeKind = vChild[1].kind
              case vChildRangeKind
              of nnkCommand:
                let minLen = vChild[1][0].intVal
                let maxLen = vChild[1][1].intVal
                var ok = ""
                var err = ""
                if vChild.len >= 3:
                  for msg in vChild[2]:
                    case $msg[0]
                    of "ok":
                      ok = $msg[1]
                    of "err":
                      err = $msg[1]
              
                fvData = nnkCall.newTree(
                  nnkDotExpr.newTree(
                    fvData,
                    newIdentNode(vChildKind)
                  ),
                  newLit(minLen),
                  newLit(maxLen),
                  newLit(err),
                  newLit(ok)
                )

              else:
                discard

            of "rangeNum":
              let vChildRangeKind = vChild[1].kind
              case vChildRangeKind
              of nnkCommand:
                let minVal = vChild[1][0].floatVal
                let maxVal = vChild[1][1].floatVal
                var ok = ""
                var err = ""
                if vChild.len >= 3:
                  for msg in vChild[2]:
                    case $msg[0]
                    of "ok":
                      ok = $msg[1]
                    of "err":
                      err = $msg[1]
                
                fvData = nnkCall.newTree(
                  nnkDotExpr.newTree(
                    fvData,
                    newIdentNode(vChildKind)
                  ),
                  newLit(minVal),
                  newLit(maxVal),
                  newLit(err),
                  newLit(ok)
                )

              else:
                discard

            of "maxNum", "minNum":
              let vChildRangeKind = vChild[1].kind
              case vChildRangeKind
              of nnkCommand:
                let val = vChild[1][0].floatVal
                var ok = ""
                var err = ""
                if vChild.len >= 3:
                  for msg in vChild[2]:
                    case $msg[0]
                    of "ok":
                      ok = $msg[1]
                    of "err":
                      err = $msg[1]
                
                fvData = nnkCall.newTree(
                  nnkDotExpr.newTree(
                    fvData,
                    newIdentNode(vChildKind)
                  ),
                  newLit(val),
                  newLit(err),
                  newLit(ok)
                )

              else:
                discard
            
            of "minLen", "maxLen":
              let vChildRangeKind = vChild[1].kind
              case vChildRangeKind
              of nnkCommand:
                let val = vChild[1][0].intVal
                var ok = ""
                var err = ""
                if vChild.len >= 3:
                  for msg in vChild[2]:
                    case $msg[0]
                    of "ok":
                      ok = $msg[1]
                    of "err":
                      err = $msg[1]
                
                fvData = nnkCall.newTree(
                  nnkDotExpr.newTree(
                    fvData,
                    newIdentNode(vChildKind)
                  ),
                  newLit(val),
                  newLit(err),
                  newLit(ok)
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

macro routes*(x: untyped): untyped =
  let stmtList = newStmtList()
  for child in x.children:
    let childKind = ($child[0]).strip
    case child.kind
    of nnkCall:
      let childStmtList = child[1]
      case childKind
      of "after":
        stmtList.add(
          nnkCall.newTree(
            nnkDotExpr.newTree(
              nnkDotExpr.newTree(
                newIdentNode("zfcoreInstance"),
                newIdentNode("r")
              ),
              newIdentNode("afterRoute")
            ),
            nnkLambda.newTree(
              newEmptyNode(),
              newEmptyNode(),
              newEmptyNode(),
              nnkFormalParams.newTree(
                newIdentNode("bool"),
                nnkIdentDefs.newTree(
                  newIdentNode("ctx"),
                  newIdentNode("HttpContext"),
                  newEmptyNode()
                ),
                nnkIdentDefs.newTree(
                  newIdentNode("route"),
                  newIdentNode("Route"),
                  newEmptyNode()
                )
              ),
              nnkPragma.newTree(
                newIdentNode("gcsafe"),
              ),
              newEmptyNode(),
              childStmtList
            )
          )
        )

      of "before":
        stmtList.add(
          nnkCall.newTree(
            nnkDotExpr.newTree(
              nnkDotExpr.newTree(
                newIdentNode("zfcoreInstance"),
                newIdentNode("r")
              ),
              newIdentNode("beforeRoute")
            ),
            nnkLambda.newTree(
              newEmptyNode(),
              newEmptyNode(),
              newEmptyNode(),
              nnkFormalParams.newTree(
                newIdentNode("bool"),
                nnkIdentDefs.newTree(
                  newIdentNode("ctx"),
                  newIdentNode("HttpContext"),
                  newEmptyNode()
                )
              ),
              nnkPragma.newTree(
                newIdentNode("gcsafe"),
              ),
              newEmptyNode(),
              childStmtList
            )
          )
        )

      else:
        stmtList.add(child)

    of nnkCommand:
      let route = ($child[1]).strip()
      case childKind
      of "get", "post", "head",
        "patch", "delete", "put",
        "options", "connect", "trace":

        let childStmtList = child[2]
        stmtList.add(
          nnkCall.newTree(
            nnkDotExpr.newTree(
              nnkDotExpr.newTree(
                newIdentNode("zfcoreInstance"),
                newIdentNode("r")
              ),
              newIdentNode(childKind)
            ),
            newLit(route),
            nnkLambda.newTree(
              newEmptyNode(),
              newEmptyNode(),
              newEmptyNode(),
              nnkFormalParams.newTree(
                newEmptyNode(),
                nnkIdentDefs.newTree(
                  newIdentNode("ctx"),
                  newIdentNode("HttpContext"),
                  newEmptyNode()
                )
              ),
              nnkPragma.newTree(
                newIdentNode("gcsafe"),
              ),
              newEmptyNode(),
              childStmtList
            )
          )
        )

      of "staticDir":
        stmtList.add(
          nnkStmtList.newTree(
            nnkCall.newTree(
              nnkDotExpr.newTree(
                nnkDotExpr.newTree(
                  newIdentNode("zfcoreInstance"),
                  newIdentNode("r")
                ),
                newIdentNode("static")
              ),
              newLit(route)
            )
          )
        )

      else:
        stmtList.add(child)

    else:
      stmtList.add(child)

  stmtList.add(
    nnkCall.newTree(
      nnkDotExpr.newTree(
        newIdentNode("zfcoreInstance"),
        newIdentNode("serve")
      )
    )
  )

  return stmtList

macro resp*(httpCode: HttpCode, body: untyped, headers: HttpHeaders = nil) =
  nnkCall.newTree(
    nnkDotExpr.newTree(
      newIdentNode("ctx"),
      newIdentNode("resp")
    ),
    httpCode,
    body,
    headers
  )

macro respHtml*(httpCode: HttpCode, body: string, headers: HttpHeaders = nil) =
  nnkCall.newTree(
    nnkDotExpr.newTree(
      newIdentNode("ctx"),
      newIdentNode("respHtml")
    ),
    httpCode,
    body,
    headers
  )

macro respRedirect*(redirectTo: string) =
  nnkCall.newTree(
    nnkDotExpr.newTree(
      newIdentNode("ctx"),
      newIdentNode("respRedirect")
    ),
    redirectTo
  )

macro setCookie*(
  cookies: StringTableRef, domain: untyped = "",
  path: untyped = "", expires: untyped = "",
  secure: untyped = false) =
  nnkCall.newTree(
    nnkDotExpr.newTree(
      newIdentNode("ctx"),
      newIdentNode("setCookie")
    ),
    cookies,
    domain,
    path,
    expires,
    secure
  )

macro getCookie*(): untyped =
  return nnkCall.newTree(
    nnkDotExpr.newTree(
      newIdentNode("ctx"),
      newIdentNode("getCookie")
    )
  )

macro clearCookie*(cookies: untyped) =
  nnkCall.newTree(
    nnkDotExpr.newTree(
      newIdentNode("ctx"),
      newIdentNode("clearCookie")
    ),
    cookies
  )

macro req*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("request")
  )

macro res*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("response")
  )

macro config*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("settings")
  )

macro client*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("client")
  )

macro ws*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("webSocket")
  )

macro params*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("params")
  )

macro reParams*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("reParams")
  )

macro formData*: untyped =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("formData")
  )

macro json*: JsonNode =
  return nnkDotExpr.newTree(
    newIdentNode("ctx"),
    newIdentNode("json")
  )

