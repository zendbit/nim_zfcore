#[
  zfcore web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#
import streams, strutils, os, times
export streams, strutils, os, times

# local
import settings
export settings

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
  #
  # Move uploaded file to the destination
  #
  let destDir = destFilePath.rsplit(DirSep, 1)[0]

  if destDir.existsDir:
    # delete target first
    if destFilePath.existsFile:
      destFilePath.removeFile

    # move the file
    self.content.moveFile(destFilePath)

    # check if file exist
  result = destFilePath.existsFile
  if result:
    # if success change the file path of the file with new destination file path
    self.content = destFilePath

proc moveFileToDir*(
  self: FileData,
  destDirPath: string): bool {.discardable.} =
  #
  # move uploaded file into the directory
  #
  let destFilePath = destDirPath.joinPath(self.content.splitPath[1])

  if destDirPath.existsDir:
    # delete target first
    if destFilePath.existsFile:
      destFilePath.removeFile

    # move the file
    self.content.moveFile(destFilePath)

  # check if file exist
  result = destFilePath.existsFile
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
  #
  # create new form data
  #
  result = FormData(fields: @[], files: @[])

#[
  Get field of form data by name and will return teh FieldData object
]#
proc getField*(
  self: FormData,
  name: string): FieldData =
  #
  # get field data by name return FieldData
  #
  for field in self.fields:
    if field.name == name:
      result = field
      break

#[
  Get uploaded file by the name and will return the FileData as result
  the file path location will be saved to the content field
]#
proc getFileByName*(
  self: FormData,
  name: string): FileData =
  #
  # get uploaded file by name, return FileData
  # saved file location in the FileData.content
  #
  for file in self.files:
    if file.name == name:
      result = file
      break

#[
  Get uploaded file by the filename and will return the FileData as result
  the file path location will be saved to the content field
]#
proc getFileByFileName*(
  self: FormData,
  name: string): FileData =
  #
  # get uploaded file by filename, return FileData
  # saved file location in the FileData.content
  #
  for file in self.files:
    if file.filename == name:
      result = file
      break

#[
  Get all field of the form data parameter
]#
proc getFields*(self: FormData): seq[FieldData] =
  #
  # get all fields data of the forms, return sequence of FieldData
  #
  result = self.fields

#[
  Get all the uploaded files from the multipart forms
]#
proc getFiles*(self: FormData): seq[FileData] =
  #
  # get all uploaded files, return sequence of FileData
  #
  result = self.files

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
  #
  # parse multipart content data string
  # allowedMime is list of allowed mime when uploading the file
  # allowedExt is list of allowed ext when uploading the file
  #
  if content != "":
    #var buff = content.split("\n")
    var boundary = ""
    var parseStep = ParseStep.boundary
    var parseType = ParseType.none
    var tmpFile = FileData()
    var tmpField = FieldData()
    var tmpFileData: FileStream
    var tmpFieldData: seq[string] = @[]
    let stream = content.newFileStream
    var line = ""

    while true:
      line &= stream.readChar
      if not line.endsWith("\c\L"):
        continue
    
      if line.strip() != boundary:
        if parseStep == ParseStep.headerEnd and
          line.strip() != "":
          parseStep = ParseStep.content

      # if boundary found
      if line.strip().startsWith(boundary) and
        boundary != "":
        # if parse content end which is line same with the boundary content
        # reset parseStep to boundary and release all stream
        if parseStep == ParseStep.content:
          # reset parseStep
          parseStep = ParseStep.boundary
          case parseType
          of ParseType.file:
            if not tmpFileData.isNil:
              tmpFileData.flush()
              tmpFileData.close()
              # save parse result to file
              if tmpFile.name == "":
                tmpFile.name = tmpFile.filename

              self.files.add(deepCopy(tmpFile))

          of ParseType.field:
            # save parse result to field
            tmpField.content = tmpFieldData.join("")

            self.fields.add(tmpField.deepCopy)
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
        let lineStrip = line.strip
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
            let hinfoStrip = hinfo.strip
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
                let hinfoKey = hinfoSplit[0].strip
                let hinfoValue = hinfoSplit[1].strip().replace("\"", "")
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
                    tmpFile.content = settings.tmpUploadDir.joinPath(
                      $(getTime().toUnix) &
                      "_" & hinfoValue)

                    tmpFileData = tmpFile.content.newFileStream(fmWrite)

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
        if not line.strip().startsWith(boundary):
          case parseType
          of ParseType.file:
            if not tmpFileData.isNil:
              tmpFileData.writeLine(line)

          of ParseType.field:
            tmpFieldData.add(line)

          else:
            discard

      else:
        discard
      
      # clear the line buffer after process
      line = ""

      if stream.atEnd:
        stream.close
        break

    # remove the content buffer from the temp
    content.removeFile

  result = self
