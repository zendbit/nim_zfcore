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

macro routes*(x: untyped): untyped =
  let stmtList = newStmtList()
  for child in x.children():
    let childKind = ($child[0]).strip()
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

