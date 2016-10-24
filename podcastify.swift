#!/usr/bin/env swift

import Foundation

let pageSize = 10
let maxPages = 10

let radioDateFormatter = DateFormatter()
radioDateFormatter.locale = Locale(identifier: "cs_CZ")
radioDateFormatter.dateFormat = "d.M.yyyy hh:mm"

let RFC822DateFormatter = DateFormatter()
RFC822DateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

struct AudioItem {
    let id: String
    let text: String
    let mediaURL: URL
    let fileSize: Int
    let pubDate: Date
}

extension XMLNode {

    func node(forXPath path: String) -> XMLNode? {
        if let candidates = try? nodes(forXPath: path) {
            return candidates.first
        } else {
            return nil
        }
    }
}

extension String {

    var trimWhitespace: String {
        return trimmingCharacters(in: .whitespaces)
    }
}

func listAllArchiveURLs() -> [URL] {
    var pageNo = 0
    var URLs: [URL] = []
    while true {
        let pageURL = URL(string: "http://hledani.rozhlas.cz/iRadio/?porad[]=Osudy&offset=\(pageNo*pageSize)")!
        let pageData = NSData(contentsOf: pageURL)
        let pageFound = (pageData != nil)
        if pageFound && pageNo < maxPages {
            URLs.append(pageURL)
            pageNo += 1
        } else {
            break
        }
    }
    return URLs
}

func listAllItemNodesAtURL(URL: URL) -> [XMLNode] {
    guard
        let document = try? XMLDocument(contentsOf: URL, options: Int(XMLNode.Options.documentTidyHTML.rawValue)),
        let rootElement = document.rootElement(),
        let nodes = try? rootElement.nodes(forXPath: "//ul[@class='box-audio-archive']")
        else { return [] }
    return nodes
}

func getFileSize(for URL: URL) -> Int {
    var request = URLRequest(url: URL)
    request.httpMethod = "HEAD"
    let semaphore = DispatchSemaphore.init(value: 0)
    var size: Int = 0
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let response = response {
            size = Int(response.expectedContentLength)
        }
        semaphore.signal()
    }
    task.resume()
    _ = semaphore.wait(timeout: .distantFuture)
    return size
}

func parseItemNode(node: XMLNode) -> AudioItem? {

    guard
        let rawTitle = node.node(forXPath: ".//*[@class='title']")?.stringValue,
        let dateStamp = node.node(forXPath: ".//*[@class='title']/*[@class='date']")?.stringValue,
        let link = node.node(forXPath: ".//*[@class='action action-player']/*/@href")?.stringValue,
        let pubDate = radioDateFormatter.date(from: dateStamp.trimWhitespace),
        let streamingURL = URL(string: link)
        else { return nil }

    let id = streamingURL.lastPathComponent
    let title = rawTitle.replacingOccurrences(of: dateStamp, with: "").trimWhitespace
    let mediaURL = URL(string: "http://media.rozhlas.cz/_audio/\(id).mp3")!
    let mediaSize = getFileSize(for: mediaURL)

    return AudioItem(id: id, text: title, mediaURL: mediaURL, fileSize: mediaSize, pubDate: pubDate)
}

func renderAudioItem(item: AudioItem) {
    print("<item>")
    print("<title>\(item.text)</title>")
    print("<link>\(item.mediaURL)</link>")
    print("<guid>\(item.mediaURL)</guid>")
    print("<enclosure url=\"\(item.mediaURL)\" type=\"audio/mpeg\" length=\"\(item.fileSize)\"/>")
    print("<pubDate>\(RFC822DateFormatter.string(from: item.pubDate))</pubDate>")
    print("</item>")
}

func renderChannel(items: [AudioItem]) {

    print("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    print("<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\" xmlns:itunes=\"http://www.itunes.com/dtds/podcast-1.0.dtd\">")

    print("<channel>")
    print("<title>Osudy</title>")
    print("<description>Autentické vzpomínky významných a zajímavých osobností zaznamenané na mikrofon a memoárová literatura převážně nežijících a zahraničních autorů čtená herci. Ojedinělá svědectví lidské paměti.</description>")
    print("<copyright>Český rozhlas Vltava</copyright>")
    print("<link>http://zoul.github.io/Osudy/</link>")

    print("<itunes:image href=\"http://i.imgur.com/hIZLilw.jpg\"/>")
    print("<itunes:explicit>No</itunes:explicit>")
    print("<itunes:category text=\"Society &amp; Culture\">")
    print("<itunes:category text=\"Personal Journals\"/>")
    print("</itunes:category>")
    print("<itunes:owner>")
    print("<itunes:name>Tomáš Znamenáček</itunes:name>")
    print("<itunes:email>tomas.znamenacek@gmail.com</itunes:email>")
    print("</itunes:owner>")

    print("<language>cs</language>")
    print("<lastBuildDate>\(RFC822DateFormatter.string(from: Date()))</lastBuildDate>")
    print("<atom:link href=\"http://zoul.github.io/Osudy/feed.xml\" rel=\"self\" type=\"application/rss+xml\" />")

    items.forEach(renderAudioItem)

    print("</channel>")
    print("</rss>")
}

renderChannel(items: listAllArchiveURLs().flatMap(listAllItemNodesAtURL).flatMap(parseItemNode))
