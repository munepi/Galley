import os.log

enum Log {
    static let file = Logger(subsystem: "com.github.munepi.galley", category: "file")
    static let forwardSearch = Logger(subsystem: "com.github.munepi.galley", category: "forwardSearch")
    static let inverseSearch = Logger(subsystem: "com.github.munepi.galley", category: "inverseSearch")
    static let sidebar = Logger(subsystem: "com.github.munepi.galley", category: "sidebar")
    static let pdfinfo = Logger(subsystem: "com.github.munepi.galley", category: "pdfinfo")
}
