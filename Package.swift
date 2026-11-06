// swift-tools-version: 6.3
#if os(Windows)
import Foundation
#endif
import PackageDescription

var products: [Product] = [
    .library(
        name: "Adwaita",
        targets: ["Adwaita"]
    ),
    .library(
        name: "DemoAppLib",
        targets: ["DemoAppLib"]
    )
]

#if !os(Windows) && !os(macOS)
products.append(
    // Opt-in WebKitGTK integration. Consumers who want the
    // ``WebView`` widget add this product to their target's
    // dependencies; everyone else is not forced to install
    // `libwebkitgtk-6.0-dev` (which is unavailable on macOS
    // Homebrew, breaking that platform's build otherwise).
    .library(
        name: "AdwaitaWebKit",
        targets: ["AdwaitaWebKit"]
    )
)
#endif

#if os(Windows)
let adwaitaBinDirURL = { () -> URL in
    (ProcessInfo.processInfo.environment["PATH"] ?? ProcessInfo.processInfo.environment["Path"])!
        .components(separatedBy: ";")
        .lazy.map(URL.init(fileURLWithPath:))
        .first(where: { url in
            (FileManager.default.subpaths(atPath: url.path(percentEncoded: false)) ?? [])
                .contains("adwaita-1-0.dll")
        }) ?? URL(fileURLWithPath: ProcessInfo.processInfo.environment["GTK_BIN_DIR"]!)
}()

let adwaitaIncludeDirURL = adwaitaBinDirURL
                            .appendingPathComponent("../include")
                            .standardizedFileURL

let adwaitaLibDirURL = adwaitaBinDirURL
                        .appendingPathComponent("../lib")
                        .standardizedFileURL

func gtkIncludeDir(_ subpath: String) -> String {
    return adwaitaIncludeDirURL.appendingPathComponent(subpath).path
}

func gtkLibDir(_ subpath: String) -> String {
    return adwaitaLibDirURL.appendingPathComponent(subpath).path
}

let includes: [String] = [
    adwaitaIncludeDirURL.path,
    gtkIncludeDir(""),
    gtkIncludeDir("libadwaita-1"),
    gtkIncludeDir("gtk-4.0"),
    gtkIncludeDir("glib-2.0"),
    gtkLibDir("glib-2.0/include"),
    gtkIncludeDir("cairo"),
    gtkIncludeDir("pango-1.0"),
    gtkIncludeDir("harfbuzz"),
    gtkIncludeDir("gdk-pixbuf-2.0"),
    gtkIncludeDir("graphene-1.0"),
    gtkLibDir("graphene-1.0/include"),
    gtkIncludeDir("gtksourceview-5"),
]

let libs: [String] = [
    "adwaita-1",
    "gtk-4",
    "glib-2.0",
    "gobject-2.0",
    "gio-2.0",
    "gmodule-2.0",
    "gtksourceview-5",
    "cairo",
    "cairo-gobject",
    "pango-1.0",
    "pangocairo-1.0",
    "pangoft2-1.0",
]

let cSettings: [CSetting] = includes.reduce(into: []) {
    $0.append(
        .unsafeFlags(["-I", $1], .when(platforms: [.windows]))
    )
}

let swiftSettings: [SwiftSetting] = includes.reduce(into: []) {
    $0.append(
        .unsafeFlags(["-Xcc", "-I", "-Xcc", $1], .when(platforms: [.windows]))
    )
}

let linkSettings: [LinkerSetting] = libs.reduce(into: [.unsafeFlags(["-L", adwaitaLibDirURL.path], .when(platforms: [.windows]))]) {
    $0.append(
        .linkedLibrary($1, .when(platforms: [.windows]))
    )
}
#else
let cSettings: [CSetting] = []
let swiftSettings: [SwiftSetting] = []
let linkSettings: [LinkerSetting] = []
#endif

var targets: [Target] = [
    .systemLibrary(
        name: "CAdwaita",
        pkgConfig: "libadwaita-1",
        providers: [
            .apt(["libadwaita-1-dev"])
        ]
    ),
    .systemLibrary(
        name: "CGtkSource",
        pkgConfig: "gtksourceview-5",
        providers: [
            .apt(["libgtksourceview-5-dev"])
        ]
    ),
    .target(
        name: "GObjectSupport",
        dependencies: ["CAdwaita"],
        cSettings: cSettings,
        swiftSettings: swiftSettings,
        linkerSettings: linkSettings
    ),
    .target(
        name: "Adwaita",
        dependencies: ["GObjectSupport", "CGtkSource"],
        cSettings: cSettings,
        swiftSettings: swiftSettings,
        linkerSettings: [
            .linkedLibrary("dl", .when(platforms: [.linux, .macOS])),
        ] + linkSettings
    ),
    .target(
        name: "DemoAppLib",
        dependencies: ["Adwaita"],
        path: "Sources/DemoAppLib",
        resources: [
            .copy("Resources")
        ]
    ),
    .executableTarget(
        name: "DemoApp",
        dependencies: ["DemoAppLib"],
        path: "Sources/DemoApp"
    ),
    .testTarget(
        name: "AdwaitaTests",
        dependencies: ["Adwaita"]
    ),
    .testTarget(
        name: "DemoAppLibTests",
        dependencies: ["DemoAppLib", "Adwaita"]
    )
]

#if !os(Windows) && !os(macOS)
targets.append(contentsOf: [
    .systemLibrary(
        name: "CWebKit",
        pkgConfig: "webkitgtk-6.0",
        providers: [
            .apt(["libwebkitgtk-6.0-dev"])
        ]
    ),
    // WebView lives in its own target so the WebKitGTK system
    // dependency stays opt-in. Importing this module pulls in
    // CWebKit (and therefore requires `libwebkitgtk-6.0-dev` on
    // apt / `webkitgtk-6.0` pkg-config on the system).
    .target(
        name: "AdwaitaWebKit",
        dependencies: ["Adwaita", "CWebKit"]
    )
])
#endif

let package = Package(
    name: "swift-adwaita",
    platforms: [
        .macOS(.v13)
    ],
    products: products,
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.3.0")
    ],
    targets: targets
)
