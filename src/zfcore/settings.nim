#[
  ZendFlow web framework for nim language
  This framework if free to use and to modify
  License: BSD
  Author: Amru Rosyada
  Email: amru.rosyada@gmail.com
  Git: https://github.com/zendbit
]#

#[
  This is setting definition
  will be much changes on the future:
    port:int -> port to be use for the sever
    staticDir:string -> where the static directory, and will serve public resource like .css, .jpg, .js etc
    address:string -> is address to be bind for starting the server
]#

import
  os

from zfblast import SslSettings

type
  # port to zfblast ssl setting
  #SslSettings* = ref object
  #    certFile*: string
  #    keyFile*: string

  Settings* = ref object
    port*: int
    address*: string
    reuseAddress*: bool
    reusePort*: bool
    maxBodyLength*: int
    debug*: bool
    appRootDir*: string
    sslSettings*: SslSettings
    # Keep-Alive header max request with given persistent timeout
    # read RFC (https://tools.ietf.org/html/rfc2616)
    # section Keep-Alive and Connection
    # for improving response performance
    keepAliveMax*: int
    # Keep-Alive timeout
    keepAliveTimeout*: int
    viewDir: string
    staticDir: string
    tmpDir: string

#[
  this for instantiate new Settings with default parameter is:
    port -> 8080
    address -> 0.0.0.0
    staticDir -> www
]#
proc newSettings*(
  appRootDir:string = "",
  port: int = 8080,
  address: string = "0.0.0.0",
  reuseAddress: bool = true,
  reusePort: bool = false,
  maxBodyLength: int = 268435456,
  debug: bool = true,
  keepAliveMax: int = 20,
  keepAliveTimeout: int = 10,
  sslSettings: SslSettings = nil): Settings =

  var instance = Settings(
    port: port,
    address: address,
    staticDir: joinPath(appRootDir ,"www"),
    tmpDir: joinPath(appRootDir, "tmp"),
    reuseAddress: reuseAddress,
    reusePort: reusePort,
    maxBodyLength: maxBodyLength,
    debug: debug,
    keepAliveMax: keepAliveMax,
    keepAliveTimeout: keepAliveTimeout,
    viewDir: joinPath(appRootDir, "views"),
    sslSettings: sslSettings)

  return instance

proc staticDir*(self: Settings): string =
  return self.staticDir

proc tmpDir*(self: Settings): string =
  return self.tmpDir

proc viewDir*(self: Settings): string =
  return self.viewDir

export
  Settings,
  SslSettings
