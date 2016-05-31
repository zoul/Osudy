import Cocoa

let pageSize = 10
let maxPages = 10

let radioDateFormatter = NSDateFormatter()
radioDateFormatter.locale = NSLocale(localeIdentifier: "cs_CZ")
radioDateFormatter.dateFormat = "d.M.yyyy hh:mm"

let RFC822DateFormatter = NSDateFormatter()
RFC822DateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

struct AudioItem {
    let id: String
    let text: String
    let mediaURL: NSURL
    let pubDate: NSDate
}

extension NSXMLNode {

    func nodeForXPath(path: String) -> NSXMLNode? {
        if let candidates = try? nodesForXPath(path) {
            return candidates.first
        } else {
            return nil
        }
    }
}

extension String {

    var trimWhitespace: String {
        return stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
    }
}

func listAllArchiveURLs() -> [NSURL] {
    var pageNo = 0
    var URLs: [NSURL] = []
    while true {
        let pageURL = NSURL(string: "http://hledani.rozhlas.cz/iRadio/?porad[]=Osudy&offset=\(pageNo*pageSize)")!
        let pageData = NSData(contentsOfURL: pageURL)
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

func listAllItemNodesAtURL(URL: NSURL) -> [NSXMLNode] {
    guard
        let document = try? NSXMLDocument(contentsOfURL: URL, options: NSXMLDocumentTidyHTML),
        let rootElement = document.rootElement(),
        let nodes = try? rootElement.nodesForXPath("//ul[@class='box-audio-archive']")
        else { return [] }
    return nodes
}

func parseItemNode(node: NSXMLNode) -> AudioItem? {

    guard
        let rawTitle = node.nodeForXPath(".//*[@class='title']")?.stringValue,
        let dateStamp = node.nodeForXPath(".//*[@class='title']/*[@class='date']")?.stringValue,
        let link = node.nodeForXPath(".//*[@class='action action-player']/*/@href")?.stringValue,
        let pubDate = radioDateFormatter.dateFromString(dateStamp.trimWhitespace),
        let streamingURL = NSURL(string: link),
        let id = streamingURL.lastPathComponent
        else { return nil }

    let title = rawTitle.stringByReplacingOccurrencesOfString(dateStamp, withString: "").trimWhitespace
    let mediaURL = NSURL(string: "http://media.rozhlas.cz/_audio/\(id).mp3")!

    return AudioItem(id: id, text: title, mediaURL: mediaURL, pubDate: pubDate)
}

func renderAudioItem(item: AudioItem) {
    print("<item>")
    print("<title>\(item.text)</title>")
    print("<link>\(item.mediaURL)</link>")
    print("<guid>\(item.mediaURL)</guid>")
    print("<enclosure url=\"\(item.mediaURL)\" type=\"audio/mpeg\"/>")
    print("<pubDate>\(RFC822DateFormatter.stringFromDate(item.pubDate))</pubDate>")
    print("</item>")
}

func renderChannelWithItems(items: [AudioItem]) {
    print("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    print("<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\" xmlns:itunes=\"http://www.itunes.com/dtds/podcast-1.0.dtd\">")
    print("<channel>")
    print("<title>Osudy</title>")
    print("<description>Autentické vzpomínky významných a zajímavých osobností zaznamenané na mikrofon a memoárová literatura převážně nežijících a zahraničních autorů čtená herci. Ojedinělá svědectví lidské paměti.</description>")
    print("<link>http://zoul.github.io/Osudy/</link>")
    print("<itunes:image href=\"http://i.imgur.com/hIZLilw.jpg\"/>")
    print("<itunes:explicit>No</itunes:explicit>")
    print("<language>cs</language>")
    print("<lastBuildDate>\(RFC822DateFormatter.stringFromDate(NSDate()))</lastBuildDate>")
    print("<atom:link href=\"http://zoul.github.io/Osudy/feed.xml\" rel=\"self\" type=\"application/rss+xml\" />")
    items.forEach { renderAudioItem($0) }
    print("</channel>")
    print("</rss>")
}

let items = listAllArchiveURLs().flatMap({ listAllItemNodesAtURL($0) }).flatMap({ parseItemNode($0) })
renderChannelWithItems(items)