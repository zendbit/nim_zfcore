#[
  zfcore web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#

import
  os,
  sugar,
  sequtils

from zfblast import SslSettings

type
  Settings* = ref object
    #
    # This is setting definition
    # will be much changes on the future:
    #   port:int -> port to be use for the sever
    #   staticDir:string -> where the static directory, and will serve public resource like .css, .jpg, .js etc
    #   address:string -> is address to be bind for starting the server
    #
    # port to zfblast ssl setting
    # SslSettings* = ref object
    #    certFile*: string
    #    keyFile*: string
    #
    port*: int
    address*: string
    reuseAddress*: bool
    reusePort*: bool
    maxBodyLength*: int
    trace*: bool
    appRootDir*: string
    sslSettings*: SslSettings
    # Keep-Alive header max request with given persistent timeout
    # read RFC (https://tools.ietf.org/html/rfc2616)
    # section Keep-Alive and Connection
    # for improving response performance
    keepAliveMax*: int
    # Keep-Alive timeout
    keepAliveTimeout*: int
    staticDir*: string
    tmpDir*: string
    uploadDir*: string
    gzipDir*: string
    tmpCleanupDir*: seq[tuple[dirName: string, interval: uint]]

proc addTmpCleanupDir*(self: Settings, dirName: string, interval: uint = 3600) =
  if filter(self.tmpCleanupDir, (x: tuple[dirName: string, interval: uint]) => x.dirName == dirName).len == 0:
    self.tmpCleanupDir.add((dirName, interval))
    
proc removeTmpCleanupDir*(self: Settings, dirname: string) =
  self.tmpCleanupDir = filter(self.tmpCleanupDir, (x: tuple[dirName: string, interval: uint]) => x.dirName != dirname)

proc newSettings*(
  appRootDir:string = getAppDir(),
  port: int = 8080,
  address: string = "0.0.0.0",
  reuseAddress: bool = true,
  reusePort: bool = false,
  maxBodyLength: int = 268435456,
  trace: bool = false,
  keepAliveMax: int = 20,
  keepAliveTimeout: int = 10,
  sslSettings: SslSettings = nil,
  tmpCleanupDir: seq[tuple[dirName: string, interval: uint]] = @[]): Settings =
  #
  # this for instantiate new Settings with default parameter is:
  #   port -> 8080
  #   address -> 0.0.0.0
  #   staticDir -> www
  #
  var instance = Settings(
    port: port,
    address: address,
    staticDir: appRootDir.joinPath("www"),
    tmpDir: appRootDir.joinPath(".tmp"),
    uploadDir: appRootDir.joinPath(".tmp", "upload"),
    gzipDir: appRootDir.joinPath(".tmp", "gzip"),
    tmpCleanupDir: tmpCleanupDir,
    reuseAddress: reuseAddress,
    reusePort: reusePort,
    maxBodyLength: maxBodyLength,
    trace: trace,
    keepAliveMax: keepAliveMax,
    keepAliveTimeout: keepAliveTimeout,
    sslSettings: sslSettings)

  if not instance.tmpDir.existsDir:
    instance.tmpDir.createDir
  if not instance.uploadDir.existsDir:
    instance.uploadDir.createDir
  if not instance.gzipDir.existsDir:
    instance.gzipDir.createDir

  instance.addTmpCleanupDir("upload")
  instance.addTmpCleanupDir("gzip")

  return instance

export
  SslSettings
