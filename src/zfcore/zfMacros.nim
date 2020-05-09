#[
  ZendFlow web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#

# this is the macro to make the coding more easy using zfcore
# simpiify the construction of routing definition
# resp, setCookie etc
import
  macros,
  strutils

proc genMiddleware(id: string, stmtList: NimNode): NimNode =
  let formalParams = nnkFormalParams.newTree(
      nnkBracketExpr.newTree(
        newIdentNode("Future"),
        newIdentNode("bool")
      ),
      nnkIdentDefs.newTree(
        newIdentNode("ctx"),
        newIdentNode("HttpCtx"),
        newEmptyNode()
      )
    )

  if id == "afterRoute":
    formalParams.add(
      nnkIdentDefs.newTree(
        newIdentNode("route"),
        newIdentNode("Route"),
        newEmptyNode()
      )
    )

  return nnkCall.newTree(
    nnkDotExpr.newTree(
      nnkDotExpr.newTree(
        newIdentNode("zfInstance"),
        newIdentNode("r")
      ),
      newIdentNode(id)
    ),
    nnkLambda.newTree(
      newEmptyNode(),
      newEmptyNode(),
      newEmptyNode(),
      formalParams,
      nnkPragma.newTree(
        newIdentNode("async")
      ),
      newEmptyNode(),
      stmtList
    )
  )

proc genRoutes(x: NimNode): NimNode =
  let stmtList = newStmtList()
  for child in x.children():
    if child.kind == nnkCommand and len(child) >= 2:
      let action = ($child[0]).strip()
      let route = ($child[1]).strip()
      case action
      of "get", "post", "head",
        "patch", "delete", "put",
        "options", "connect", "trace":

        let childStmtList = child[2]
        let routeDef = nnkCall.newTree(
            nnkDotExpr.newTree(
              nnkDotExpr.newTree(
                newIdentNode("zfInstance"),
                newIdentNode("r")
              ),
              newIdentNode(action)
            ),
            newLit(route),
            nnkLambda.newTree(
              newEmptyNode(),
              newEmptyNode(),
              newEmptyNode(),
              nnkFormalParams.newTree(
                nnkBracketExpr.newTree(
                  newIdentNode("Future"),
                  newIdentNode("void")
                ),
                nnkIdentDefs.newTree(
                  newIdentNode("ctx"),
                  newIdentNode("HttpCtx"),
                  newEmptyNode()
                )
              ),
              nnkPragma.newTree(
                newIdentNode("async")
              ),
              newEmptyNode(),
              childStmtList
            )
          )

        stmtList.add(routeDef)

      of "staticDir":
        stmtList.add(
          nnkStmtList.newTree(
            nnkCall.newTree(
              nnkDotExpr.newTree(
                nnkDotExpr.newTree(
                  newIdentNode("zfInstance"),
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

  return stmtList

macro zf*(x: untyped): untyped =
  let stmtList = nnkStmtList.newTree(
      nnkLetSection.newTree(
        nnkIdentDefs.newTree(
          newIdentNode("zfInstance"),
          newEmptyNode(),
          newCall(
            newIdentNode("newZendFlow")
          )
        )
      )
    )

  for child in x.children():
    if child.kind == nnkCall:
      let action = $child[0]
      case action
      of "beforeRoute", "afterRoute":
        stmtList.add(genMiddleware(action, child[1]))

      of "routes":
        stmtList.add(genRoutes(child[1]))

      else:
        stmtList.add(child)

    else:
      stmtList.add(child)

  return stmtList

macro resp*(httpCode: untyped, body: untyped, headers: untyped = nil) =
  nnkCall.newTree(
    nnkDotExpr.newTree(
      newIdentNode("ctx"),
      newIdentNode("resp")
    ),
    httpCode,
    body,
    headers
  )

macro respRedirect*(redirectTo: untyped) =
  nnkCall.newTree(
    nnkDotExpr.newTree(
      newIdentNode("ctx"),
      newIdentNode("respRedirect")
    ),
    redirectTo
  )

macro setCookie*(
  cookies: untyped, domain: untyped = "",
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

macro serve*() =
  nnkStmtList.newTree(
    nnkCall.newTree(
      nnkDotExpr.newTree(
        newIdentNode("zfInstance"),
        newIdentNode("serve")
      )
    )
  )

export
  macros

