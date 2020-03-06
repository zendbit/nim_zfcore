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

import os

type
    Settings* = ref object
        port*: int
        staticDir*: string
        tmpDir*: string
        address*: string
        reuseAddr*: bool
        reusePort*: bool
        maxBody*: int
        debug*: bool
        appRootDir*: string
        viewDir*: string

#[
    this for instantiate new Settings with default parameter is:
        port -> 8080
        address -> 0.0.0.0
        staticDir -> www
]#
proc newSettings*(appRootDir:string = "", port: int = 8080, address: string = "0.0.0.0",
        staticDir: string = "www", tmpDir: string = "tmp", reuseAddr: bool = true,
        reusePort:bool = false, maxBody:int = 8388608, debug:bool = true, viewDir: string = "views"): Settings =

    var instance = Settings(
        port: port,
        address: address,
        staticDir: joinPath(appRootDir ,staticDir),
        tmpDir: joinPath(appRootDir, tmpDir),
        reuseAddr: reuseAddr,
        reusePort: reusePort,
        maxBody: maxBody,
        debug: debug,
        viewDir: joinPath(appRootDir, viewDir))
    return instance

export Settings
