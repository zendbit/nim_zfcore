#[
    ZendFlow web framework for nim language
    This framework if free to use and to modify
    License: BSD
    Author: Amru Rosyada
    Email: amru.rosyada@gmail.com
    Git: https://github.com/zendbit
]#

import
    strutils,
    strformat

type
    Mime = ref object
        mimeApp: seq[string]
        mimeSnd: seq[string]
        mimeImg: seq[string]
        mimeMail: seq[string]
        mimeTxt: seq[string]
        mimeVid: seq[string]
        mimeVW: seq[string]
        mimeFont: seq[string]

proc newMimeType*(): Mime =
    result = Mime(
        mimeApp: @[
            "|.evy|=application/envoy",
            "|.fif|=application/fractals",
            "|.spl|=application/futuresplash",
            "|.hta|=application/hta",
            "|.acx|=application/internet-property-stream",
            "|.hqx|=application/mac-binhex40",
            "|.doc|.dot|=application/msword",
            "|*|.bin|.class|.dms|.exe|.lha|.lzh|=application/octet-stream",
            "|.oda|=application/oda",
            "|.axs|=application/olescript",
            "|.pdf|=application/pdf",
            "|.prf|=application/pics-rules",
            "|.p10|=application/pkcs10",
            "|.crl|=application/pkix-crl",
            "|.ai|.eps|.ps|=application/postscript",
            "|.rtf|=application/rtf",
            "|.setpay|=application/set-payment-initiation",
            "|.setreg|=application/set-registration-initiation",
            "|.xla|.xlc|.xlm|.xls|.xlt|.xlw|=application/vnd.ms-excel",
            "|.msg|=application/vnd.ms-outlook",
            "|.sst|=application/vnd.ms-pkicertstore",
            "|.cat|=application/vnd.ms-pkiseccat",
            "|.stl|=application/vnd.ms-pkistl",
            "|.pot|.pps|.ppt|=application/vnd.ms-powerpoint",
            "|.mpp|=application/vnd.ms-project",
            "|.wcm|.wdb|.wks|.wps|=application/vnd.ms-works",
            "|.hlp|=application/winhlp",
            "|.bcpio|=application/x-bcpio",
            "|.cdf|=application/x-cdf",
            "|.z|=application/x-compress",
            "|.tgz|=application/x-compressed",
            "|.cpio|=application/x-cpio",
            "|.csh|=application/x-csh",
            "|.dcr|.dxr|.dir|=application/x-director",
            "|.dvi|=application/x-dvi",
            "|.gtar|=application/x-gtar",
            "|.gz|=application/x-gzip",
            "|.hdf|=application/x-hdf",
            "|.ins|.isp|=application/x-internet-signup",
            "|.iii|=application/x-iphone",
            "|.js|=application/x-javascript",
            "|.latex|=application/x-latex",
            "|.mdb|=application/x-msaccess",
            "|.crd|=application/x-mscardfile",
            "|.clp|=application/x-msclip",
            "|.dll|=application/x-msdownload",
            "|.m13|.m14|.mvb|=application/x-msmediaview",
            "|.wmf|=application/x-msmetafile",
            "|.mny|=application/x-msmoney",
            "|.pub|=application/x-mspublisher",
            "|.scd|=application/x-msschedule",
            "|.trm|=application/x-msterminal",
            "|.wri|=application/x-mswrite",
            "|.cdf|=application/x-netcdf",
            "|.nc|=application/x-netcdf",
            "|.pma|.pmc|.pml|.pmr|.pmw|=application/x-perfmon",
            "|.p12|.pfx|=application/x-pkcs12",
            "|.p7b|.spc|.p7r|=application/x-pkcs7-certificates",
            "|.p7c|.p7m|=application/x-pkcs7-mime",
            "|.p7s|=application/x-pkcs7-signature",
            "|.sh|=application/x-sh",
            "|.shar|=application/x-shar",
            "|.swf|=application/x-shockwave-flash",
            "|.sit|=application/x-stuffit",
            "|.sv4cpio|=application/x-sv4cpio",
            "|.sv4crc|=application/x-sv4crc",
            "|.tar|=application/x-tar",
            "|.tcl|=application/x-tcl",
            "|.text|=application/x-tex",
            "|.texi|=application/x-texinfo",
            "|.texinfo|=application/x-texinfo",
            "|.roff|=application/x-troff",
            "|.t|.tr|=application/x-troff",
            "|.man|=application/x-troff-man",
            "|.me|=application/x-troff-me",
            "|.ms|=application/x-troff-ms",
            "|.ustar|=application/x-ustar",
            "|.src|=application/x-wais-source",
            "|.cer|.crt|.der|=application/x-x509-ca-cert",
            "|.pko|=application/ynd.ms-pkipko",
            "|.zip|=application/zip",
            "|.abw|=application/x-abiword",
            "|.arc|=application/x-freearc",
            "|.azw|=application/vnd.amazon.ebook",
            "|.bz|=application/x-bzip",
            "|.bz2|=application/x-bzip2",
            "|.docx|=application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "|.eot|=application/vnd.ms-fontobject",
            "|.epub|=application/epub+zip",
            "|.jar|=application/java-archive",
            "|.json|=application/json",
            "|.jsonld|=application/ld+json",
            "|.mpkg|=application/vnd.apple.installer+xml",
            "|.odp|=application/vnd.oasis.opendocument.presentation",
            "|.ods|=application/vnd.oasis.opendocument.spreadsheet",
            "|.odt|=application/vnd.oasis.opendocument.text",
            "|.ogx|=application/ogg",
            "|.php|=application/php",
            "|.pptx|=application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "|.rar|=application/vnd.rar",
            "|.tar|=application/x-tar",
            "|.vsd|=application/vnd.visio",
            "|.xhtml|=application/xhtml+xml",
            "|.xlsx|=application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "|.xml|=application/xml",
            "|.xul|=application/vnd.mozilla.xul+xml",
            "|.7z|=application/x-7z-compressed"
        ],
        mimeSnd: @[
            "|.au|.snd|=audio/basic",
            "|.mid|.rmi|=audio/midi",
            "|.midi|=audio/x-midi",
            "|.mp3|=audio/mpeg",
            "|.aif|.aifc|.aiff|=audio/x-aiff",
            "|.m3u|=audio/x-mpegurl",
            "|.ra|.ram|=audio/x-pn-realaudio",
            "|.wav|=audio/x-wav",
            "|.aac|=audio/aac",
            "|.ogg|=audio/ogg",
            "|.opus|=audio/opus",
            "|.weba|=audio/webm",
            "|.3gp|=audio/3gpp",
            "|.3g2|=audio/3gpp2"
        ],
        mimeImg: @[
            "|.bmp|=image/bmp",
            "|.cod|=image/cis-cod",
            "|.gif|=image/gif",
            "|.ief|=image/ief",
            "|.jpe|.jpeg|.jpg|=image/jpeg",
            "|.jfif|=image/pipeg",
            "|.svg|=image/svg+xml",
            "|.tif|.tiff|=image/tiff",
            "|.ras|=image/x-cmu-raster",
            "|.cmx|=image/x-cmx",
            "|.ico|=image/x-icon",
            "|.pnm|=image/x-portable-anymap",
            "|.pbm|=image/x-portable-bitmap",
            "|.pgm|=image/x-portable-graymap",
            "|.ppm|=image/x-portable-pixmap",
            "|.rgb|=image/x-rgb",
            "|.xbm|=image/x-xbitmap",
            "|.xpm|=image/x-xpixmap",
            "|.xwd|=image/x-xwindowdump",
            "|.webp|=image/webp"
        ],
        mimeMail: @[
            "|.mht|=message/rfc822",
            "|.mhtml|=message/rfc822",
            "|.nws|=message/rfc822"
        ],
        mimeTxt: @[
            "|.css|=text/css",
            "|.323|=text/h323",
            "|.html|.htm|.stm|=text/html",
            "|.uls|=text/iuls",
            "|.bas|.c|.h|.txt|=text/plain",
            "|.rtx|=text/richtext",
            "|.sct|=text/scriptlet",
            "|.tsv|=text/tab-separated-values",
            "|.htt|=text/webviewhtml",
            "|.htc|=text/x-component",
            "|.ext|=text/x-setext",
            "|.vcf|=text/x-vcard",
            "|.csv|=text/csv",
            "|.ics|=text/calendar",
            "|.mjs|=text/javascript",
            "|.xml|=text/xml"
        ],
        mimeVid: @[
            "|.mp2|.mpa|.mpe|.mpeg|.mpg|.mpv2|=video/mpeg",
            "|.mp4|=video/mp4",
            "|.mov|=video/quicktime",
            "|.qt|=video/quicktime",
            "|.lsf|.lsx|=video/x-la-asf",
            "|.asf|.asr|.asx|=video/x-ms-asf",
            "|.avi|=video/x-msvideo",
            "|.movie|=video/x-sgi-movie",
            "|.ogv|=video/ogg",
            "|.ts|=video/mp2t",
            "|.webm|=video/webm",
            "|.3gp|=video/3gpp",
            "|.3g2|=video/3gpp2"
        ],
        mimeVW: @[
            "|.frl|.vrml|.wrl|.wrz|.xaf|.xof|=x-world/x-vrml"
        ],
        mimeFont: @[
            "|.otf|=font/otf",
            "|.ttf|=font/ttf",
            "|.woff|=font/woff",
            "|.woff2|=font/woff2"
        ])

proc getMimeType(self: Mime, mimeSeq: seq[string], ext: string): string =
    for m in mimeSeq:
        if m.contains(&"|{ext.toLower()}|"):
            return m.split('=')[1]

proc getMimeType*(self: Mime, ext: string): string =
    let allMime = self.mimeTxt & self.mimeFont & self.mimeImg & self.mimeApp &
            self.mimeSnd & self.mimeVid & self.mimeMail & self.mimeVW
    for m in allMime:
        if m.contains(&"|{ext.toLower()}|"):
            return m.split('=')[1]

proc getAppMimeType*(self: Mime, ext: string): string =
    return self.getMimeType(self.mimeApp, ext)

proc getFontMimeType*(self: Mime, ext: string): string =
    return self.getMimeType(self.mimeFont, ext)

proc getSndMimeType*(self: Mime, ext: string): string =
    return self.getMimeType(self.mimeSnd, ext)

proc getImgMimeType*(self: Mime, ext: string): string =
    return self.getMimeType(self.mimeImg, ext)

proc getMailMimeType*(self: Mime, ext: string): string =
    return self.getMimeType(self.mimeMail, ext)

proc getTxtMimeType*(self: Mime, ext: string): string =
    return self.getMimeType(self.mimeTxt, ext)

proc getVidMimeType*(self: Mime, ext: string): string =
    return self.getMimeType(self.mimeVid, ext)

proc getVWMimeType*(self: Mime, ext: string): string =
    return self.getMimeType(self.mimeVW, ext)
