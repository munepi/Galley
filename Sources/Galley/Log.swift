import os.log

enum Log {
    static let file = Logger(subsystem: "com.github.munepi.galley", category: "file")
    static let forwardSearch = Logger(subsystem: "com.github.munepi.galley", category: "forwardSearch")
    static let inverseSearch = Logger(subsystem: "com.github.munepi.galley", category: "inverseSearch")
}
