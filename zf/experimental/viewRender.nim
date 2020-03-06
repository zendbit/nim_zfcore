#[
    ZendFlow web framework for nim language
    This framework if free to use and to modify
    License: BSD
    Author: Amru Rosyada
    Email: amru.rosyada@gmail.com
    Git: https://github.com/zendbit
]#
import
    streams,
    os,
    strformat,
    strutils,
    re

type
    ViewRender* = ref object

proc readFile(self:ViewRender, path:string): string =
    if fileExists(path):
        let fStream = newFileStream(path)
        let fCtn = fStream.readAll()
        fStream.close()
        return fCtn

#[
    Return view info:
        viewPath -> view path location
        viewDir -> view directory location
        exist -> true if requested view file eixst
]#
proc viewInfo(self: ViewRender, viewDir, view: string):
        tuple[viewPath: string, viewDir: string, exist: bool] =
    let vFile = joinPath(viewDir, &"{view.replace('.', DirSep)}.html")
    let vDir = splitPath(vFile)[0]
    return (viewPath: vFile, viewDir: vDir, exist: fileExists(vFile))

#[
    Recursive parse and merge the views tag
]#
proc parseView(self: ViewRender, viewDir: string, view: string; tags: seq[string] = @[];
        parsedView: string = ""): string {. discardable .}=

    let pView = parsedView
    let (vFile, vDir, vExist) = self.viewInfo(viewDir, view)
    if vExist:
        var vCtn = self.readFile(vFile)
        let vTags = findAll(vCtn, re"\[\[[\w]+[\s]+[\w]+\]\]")
        return self.parseView(vDir, "", vTags, vCtn)

    elif tags.len != 0:
        var tmpTags = deepCopy(tags)
        var tag = tmpTags.pop()
        var vTags: array[2, string]
        if match(tag, re"\[\[([\w]+)[\s]+([\w]+)\]\]*$", vTags):
            case vTags[0]
            of "layout":
                let lyFile = joinPath(vDir, &"{vTags[1]}Layout.html")
                if fileExists(lyFile):
                    let lyCtn = self.readFile(lyFile)
                    let vCtn = lyCtn.replace("[[render body]]", pView)
                        .replace(tag, "")
                    return self.parseView(vDir, "", tmpTags, vCtn)
            of "part":
                let partVFile = joinPath(vDir, &"{vTags[1]}Part.html")
                if fileExists(partVFile):
                    let vCtn = pView.replace(tag, self.readFile(partVFile))
                    return self.parseView(vDir, "", tmpTags, vCtn)
            else:
                discard

    if tags.len == 0:
        # try to find the parsed tags on the parsed view if any
        let vTags = findAll(pView, re"\[\[[\w]+[\s]+[\w]+\]\]")
        if vTags.len != 0:
            return self.parseView(vDir, "", vTags, pView)
        else:
            return pView


proc render*(viewDir, view: string): string =
    var vr = ViewRender()
    return vr.parseView(viewDir, view)
