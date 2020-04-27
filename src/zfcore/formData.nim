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
  strutils,
  os,
  times,
  settings

type
  ParseType = enum
    none,
    file,
    field

  ParseStep = enum
    boundary,
    headerStart,
    headerEnd,
    content

  FieldData* = ref object of RootObj
    name*: string
    contentDisposition*: string
    content*: string

type
  # inherit from FieldData
  FileData* = ref object of FieldData
    filename*: string
    contentType*: string

proc moveFileTo*(
  self: FileData,
  destFilePath: string): bool {.discardable.} =

  # get destination directory
  let destDir = rsplit(destFilePath, DirSep, 1)[0]

  if existsDir(destDir):
    # delete target first
    if existsFile(destFilePath):
      removeFile(destFilePath)

    # move the file
    moveFile(self.content, destFilePath)

    # check if file exist
  result = existsFile(destFilePath)
  if result:
    # if success change the file path of the file with new destination file path
    self.content = destFilePath

proc moveFileToDir*(
  self: FileData,
  destDirPath: string): bool {.discardable.} =

  # get destination directory
  let destFilePath = joinPath(
    destDirPath,
    splitPath(self.content)[1])

  if existsDir(destDirPath):
    # delete target first
    if existsFile(destFilePath):
      removeFile(destFilePath)

    # move the file
    moveFile(
      self.content,
      destFilePath)

  # check if file exist
  result = existsFile(destFilePath)
  if result:
    # if success change the file path of the file with new destination file path
    self.content = destFilePath

type
  FormData* = ref object
    fields: seq[FieldData]
    files: seq[FileData]

#[
  Create form data instance with default tmp to stored uploded files
]#
proc newFormData*(): FormData =

  return FormData(fields: @[], files: @[])

#[
  Get field of form data by name and will return teh FieldData object
]#
proc getField*(
  self: FormData,
  name: string): FieldData =

  for field in self.fields:
    if field.name == name:
      return field

#[
  Get uploaded file by the name and will return the FileData as result
  the file path location will be saved to the content field
]#
proc getFileByName*(
  self: FormData,
  name: string): FileData =

  for file in self.files:
    if file.name == name:
      return file

#[
  Get uploaded file by the filename and will return the FileData as result
  the file path location will be saved to the content field
]#
proc getFileByFileName*(
  self: FormData,
  name: string): FileData =

  for file in self.files:
    if file.filename == name:
      return file

#[
  Get all field of the form data parameter
]#
proc getFields*(self: FormData): seq[FieldData] =

  return self.fields

#[
  Get all the uploaded files from the multipart forms
]#
proc getFiles*(self: FormData): seq[FileData] =

  return self.files

#[
  Start parsing the multipart data content
  this process seems to be complicated but actually not :-D
]#
proc parse*(
  self: FormData,
  content: string,
  settings: Settings,
  allowedMime: seq[string] = @[],
  allowedExt: seq[string] = @[]): FormData =

  if content != "":
    var buff = content.split("\n")
    var boundary = ""
    var parseStep = ParseStep.boundary
    var parseType = ParseType.none
    var tmpFile = FileData()
    var tmpField = FieldData()
    var tmpFileData: FileStream
    var tmpFieldData: seq[string] = @[]

    for line in buff:
      if line.strip() != boundary:
        if parseStep == ParseStep.headerEnd and
          line.strip() != "":
          parseStep = ParseStep.content

      # if boundary found
      if line.strip() == boundary and
        boundary != "":
        # if parse content end which is line same with the boundary content
        # reset parseStep to boundary and release all stream
        if parseStep == ParseStep.content:
          # reset parseStep
          parseStep = ParseStep.boundary
          case parseType
          of ParseType.file:
            if not isNil(tmpFileData):
              tmpFileData.flush()
              tmpFileData.close()
              # save parse result to file
              if tmpFile.name == "":
                tmpFile.name = tmpFile.filename

              self.files.add(deepCopy(tmpFile))

          of ParseType.field:
            # save parse result to field
            tmpField.content = join(
              tmpFieldData,
              "")

            self.fields.add(deepCopy(tmpField))
            tmpFieldData = @[]

          else:
            discard

          # reset oarseType
          parseType = ParseType.none

      case parseStep
      # get boundary on first read
      of ParseStep.boundary:
        boundary = line.strip()
        # set next chunk to true
        parseStep = ParseStep.headerStart

      # read header of chunk
      # this will define which is file header or field header
      of ParseStep.headerStart:
        let lineStrip = line.strip()
        if lineStrip != "":
          # split header with ; delimiter
          let hdata = line.split(';')
          # should define when read first line of header contein filename or not
          # if contein fileneme set parstType to file
          if parseType == ParseType.none:
              if lineStrip.find("filename=") != -1:
                  parseType = ParseType.file

              else:
                  parseType = ParseType.field

          # parse each header data section after split with ; character
          for hinfo in hdata:
              let hinfoStrip = hinfo.strip()
              if hinfoStrip != "":
                # parse to file if parseType is file from previous readline
                var hinfoSplit: seq[string] = @[]
                # parse content information header
                if hinfoStrip.find("Content-Disposition:") != -1 or
                  hinfoStrip.find("Content-Type:") != -1:
                  hinfoSplit = hinfoStrip.split(':')

                # parse content name and value
                elif hinfoStrip.find("name=") != -1 or
                  hinfoStrip.find("filename=") != -1:
                  hinfoSplit = hinfoStrip.split('=')

                if hinfoSplit.len == 2:
                  let hinfoKey = hinfoSplit[0].strip()
                  let hinfoValue = hinfoSplit[1].strip().replace(
                          "\"", "")
                  # parse file
                  case parseType
                  of ParseType.file:
                    case hinfoKey
                    of "Content-Disposition":
                      tmpFile.contentDisposition = hinfoValue
                    of "name":
                      tmpFile.name = hinfoValue
                    of "filename":
                      tmpFile.filename = hinfoValue
                      tmpFile.content = joinPath(
                        settings.tmpDir,
                        $toUnix(getTime()) &
                        "_" & hinfoValue)

                      tmpFileData = newFileStream(
                        tmpFile.content,
                        fmWrite)

                    of "Content-Type":
                      tmpFile.contentType = hinfoValue

                    else:
                      discard

                  # parse field
                  of ParseType.field:
                    case hinfoKey
                    of "Content-Disposition":
                      tmpField.contentDisposition = hinfoValue

                    of "name":
                      tmpField.name = hinfoValue

                    else:
                      discard

                  else:
                    discard
        else:
          parseStep = ParseStep.headerEnd

      of ParseStep.content:
        case parseType
        of ParseType.file:
          if not isNil(tmpFileData):
            tmpFileData.writeLine(line)

        of ParseType.field:
          tmpFieldData.add(line)

        else:
          discard

      else:
          discard

  return self
