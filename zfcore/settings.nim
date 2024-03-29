##
##  zfcore web framework for nim language
##  This framework if free to use and to modify
##  License: BSD
##  Author: Amru Rosyada
##  Email: amru.rosyada@gmail.com
##  Git: https://github.com/zendbit/nim.zfcore
##

##  std import
import
  os,
  sugar,
  sequtils,
  net,
  json

export
  os,
  sugar,
  sequtils,
  net,
  json

##  zfblast import
from zfblast/server import SslSettings
export SslSettings

type
  Settings* = ref object of RootObj
    ##
    ##  This is setting definition
    ##  will be much changes on the future:
    ##  
    ##  port:int -> port to be use for the sever
    ##  staticDir:string -> where the static directory, and will serve public resource like .css, .jpg, .js etc
    ##  address:string -> is address to be bind for starting the server
    ##
    ##  port to zfblast ssl setting
    ##  SslSettings* = ref object
    ##    certFile*: string
    ##    keyFile*: string
    ##
    port*: Port
    address*: string
    reuseAddress*: bool
    reusePort*: bool
    maxBodyLength*: int
    maxResponseBodyLength*: int64
    trace*: bool
    appRootDir*: string
    sslSettings*: SslSettings
    # Keep-Alive header max request with given persistent timeout
    # read RFC (https://tools.ietf.org/html/rfc2616)
    # section Keep-Alive and Connection
    # for improving response performance
    keepAlive*: bool
    staticDir*: string
    tmpDir*: string
    tmpUploadDir*: string
    tmpBodyDir*: string
    tmpGzDir*: string
    readBodyBuffer*: int
    responseRangeBuffer*: int
    tmpCleanupDir*: seq[CleanupDir]
    contentTypeToCompress*: seq[string]

  CleanupDir* = ref object of RootObj
    dirName*: string
    expired*: int64

proc `%`*(port: Port): JsonNode =
  result = % port.int

proc addTmpCleanupDir*(
  self: Settings,
  dirName: string,
  expired: int64 = 3600) =
  ##
  ##  add cleanup dir:
  ##
  ##  register directory for cleanup.
  ##  the system using folder .tmp for cache the data and will check and cleanup the folder with expired in seconds.
  ##
  if filter(self.tmpCleanupDir, (x: CleanupDir) => x.dirName == dirName).len == 0:
    self.tmpCleanupDir.add(
      CleanupDir(
        dirName: dirName,
        expired: expired
      )
    )

proc removeTmpCleanupDir*(
  self: Settings,
  dirname: string) =
  ##
  ##  remove cleanup dir:
  ##
  ##  remove direcotory from cleanup.
  ##
  self.tmpCleanupDir = filter(self.tmpCleanupDir, (x: CleanupDir) => x.dirName != dirname)

proc newSettings*(
  appRootDir:string = getAppDir(),
  port: Port = 8080.Port,
  address: string = "0.0.0.0",
  reuseAddress: bool = true,
  reusePort: bool = false,
  maxBodyLength: int = 268435456,
  readBodyBuffer: int = 51200,
  responseRangeBuffer: int = 51200,
  maxResponseBodyLength: int64 = 52428800,
  trace: bool = false,
  keepAlive: bool = false,
  sslSettings: SslSettings = nil,
  tmpCleanupDir: seq[CleanupDir] = @[],
  contentTypeToCompress: seq[string] = @[]): Settings =

  ##
  ##  this for instantiate new Settings with default parameter is:
  ##  port -> 8080
  ##  address -> 0.0.0.0
  ##  staticDir -> www
  ##
  var instance = Settings(
    port: port,
    address: address,
    staticDir: appRootDir.joinPath("www"),
    tmpDir: appRootDir.joinPath(".tmp"),
    tmpUploadDir: appRootDir.joinPath(".tmp", "upload"),
    tmpBodyDir: appRootDir.joinPath(".tmp", "body"),
    tmpGzDir: appRootDir.joinPath(".tmp", "gzip"),
    tmpCleanupDir: tmpCleanupDir,
    reuseAddress: reuseAddress,
    reusePort: reusePort,
    maxBodyLength: maxBodyLength,
    readBodyBuffer: readBodyBuffer,
    responseRangeBuffer: responseRangeBuffer,
    maxResponseBodyLength: maxResponseBodyLength,
    trace: trace,
    keepAlive: keepAlive,
    sslSettings: sslSettings,
    contentTypeToCompress: contentTypeToCompress)

  if not instance.tmpDir.existsDir:
    instance.tmpDir.createDir
  if not instance.tmpUploadDir.existsDir:
    instance.tmpUploadDir.createDir
  if not instance.tmpBodyDir.existsDir:
    instance.tmpBodyDir.createDir
  if not instance.tmpGzDir.existsDir:
    instance.tmpGzDir.createDir

  instance.addTmpCleanupDir("upload", 86400)
  instance.addTmpCleanupDir("body", 86400)
  instance.addTmpCleanupDir("gzip", 86400)

  result = instance

