import Foundation
import CoreLocation

struct WebcamEntry: Identifiable {
    let id: Int
    let name: String
    let coordinate: CLLocationCoordinate2D
    /// Bearing (degrees, 0=N) the camera faces outward toward the sea.
    let facingBearing: Double
    /// Skyline page URL — fetched at runtime to extract the live HLS stream token.
    let pageURL: URL?

    var snapshotURL: URL {
        URL(string: "https://cdn.skylinewebcams.com/live\(id).jpg")!
    }

    private static func skyline(_ path: String) -> URL? {
        URL(string: "https://www.skylinewebcams.com/en/webcam/malta/\(path).html")
    }

    static let coastal: [WebcamEntry] = [
        // facingBearing = direction the camera looks outward toward open sea (degrees, 0=N)
        WebcamEntry(id: 207,  name: "Grand Harbour",           coordinate: CLLocationCoordinate2D(latitude: 35.8979, longitude: 14.5125), facingBearing: 220, pageURL: skyline("malta/floriana/grand-harbour-valletta-waterfront")),
        WebcamEntry(id: 4000, name: "Grand Harbour Entrance",  coordinate: CLLocationCoordinate2D(latitude: 35.9003, longitude: 14.5069), facingBearing: 185, pageURL: skyline("malta/valletta/grand-harbour-entrance")),
        WebcamEntry(id: 257,  name: "Valletta Seaside",        coordinate: CLLocationCoordinate2D(latitude: 35.8933, longitude: 14.5228), facingBearing: 135, pageURL: skyline("malta/valletta/valletta-seaside-promenade")),
        WebcamEntry(id: 213,  name: "Marsaxlokk",              coordinate: CLLocationCoordinate2D(latitude: 35.8414, longitude: 14.5437), facingBearing: 160, pageURL: skyline("malta/marsaxlokk/marsaxlokk-harbour")),
        WebcamEntry(id: 261,  name: "Marsaxlokk Promenade",    coordinate: CLLocationCoordinate2D(latitude: 35.8403, longitude: 14.5453), facingBearing: 160, pageURL: skyline("malta/marsaxlokk/marsaxlokk-seaside-promenade")),
        WebcamEntry(id: 214,  name: "Birżebbuġa / Pretty Bay", coordinate: CLLocationCoordinate2D(latitude: 35.8222, longitude: 14.5250), facingBearing: 175, pageURL: skyline("malta/birzebbuga/birzebbuga-beach-pretty-bay")),
        WebcamEntry(id: 5223, name: "St. George's Bay",        coordinate: CLLocationCoordinate2D(latitude: 35.9206, longitude: 14.4878), facingBearing:  45, pageURL: skyline("malta/st-julians/st-george-beach")),
        WebcamEntry(id: 786,  name: "Golden Bay",              coordinate: CLLocationCoordinate2D(latitude: 35.9542, longitude: 14.3328), facingBearing: 295, pageURL: skyline("malta/mellieha/golden-bay")),
        WebcamEntry(id: 755,  name: "Ċirkewwa Bay",            coordinate: CLLocationCoordinate2D(latitude: 35.9853, longitude: 14.3367), facingBearing: 345, pageURL: skyline("malta/cirkewwa/cirkewwa-bay")),
        WebcamEntry(id: 754,  name: "Paradise Bay",            coordinate: CLLocationCoordinate2D(latitude: 35.9878, longitude: 14.3294), facingBearing: 315, pageURL: skyline("malta/cirkewwa/paradise-bay")),
        WebcamEntry(id: 626,  name: "Ċirkewwa Water's Edge",   coordinate: CLLocationCoordinate2D(latitude: 35.9858, longitude: 14.3342), facingBearing: 340, pageURL: skyline("malta/cirkewwa/cirkewwa-waters-edge")),
        WebcamEntry(id: 356,  name: "Sliema / St. Julian's",   coordinate: CLLocationCoordinate2D(latitude: 35.9094, longitude: 14.5006), facingBearing:  55, pageURL: skyline("malta/sliema/sliema-waters-edge")),
        WebcamEntry(id: 4455, name: "Sliema Harbour",          coordinate: CLLocationCoordinate2D(latitude: 35.9033, longitude: 14.5072), facingBearing: 100, pageURL: skyline("malta/valletta/sliema-harbour")),
        WebcamEntry(id: 3372, name: "St. Paul's Bay",          coordinate: CLLocationCoordinate2D(latitude: 35.9500, longitude: 14.3994), facingBearing: 335, pageURL: skyline("malta/st-paul-s-bay/malta-st-paul-s-bay")),
        WebcamEntry(id: 5304, name: "Buġibba",                 coordinate: CLLocationCoordinate2D(latitude: 35.9511, longitude: 14.4183), facingBearing: 350, pageURL: skyline("malta/bugibba/st-pauls-bay")),
        WebcamEntry(id: 254,  name: "Wied iż-Żurrieq",         coordinate: CLLocationCoordinate2D(latitude: 35.8181, longitude: 14.4492), facingBearing: 180, pageURL: skyline("malta/qrendi/wied-iz-zurrieq")),
        WebcamEntry(id: 221,  name: "Marsalforn Bay (Gozo)",   coordinate: CLLocationCoordinate2D(latitude: 36.0736, longitude: 14.2544), facingBearing: 350, pageURL: skyline("gozo/marsalforn/marsalforn-bay")),
        WebcamEntry(id: 864,  name: "Mġarr Harbour (Gozo)",    coordinate: CLLocationCoordinate2D(latitude: 36.0194, longitude: 14.2983), facingBearing: 160, pageURL: skyline("gozo/mgarr/gozo-mgarr")),
    ]
}

// MARK: - Map pins (cameras grouped by proximity)

struct WebcamPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let cameras: [WebcamEntry]

    static let all: [WebcamPin] = {
        let e = WebcamEntry.coastal
        func cams(_ ids: [Int]) -> [WebcamEntry] { e.filter { ids.contains($0.id) } }
        return [
            WebcamPin(id: "grand-harbour", coordinate: CLLocationCoordinate2D(latitude: 35.8972, longitude: 14.5141),
                      cameras: cams([207, 4000, 257])),
            WebcamPin(id: "marsaxlokk",    coordinate: CLLocationCoordinate2D(latitude: 35.8408, longitude: 14.5445),
                      cameras: cams([213, 261])),
            WebcamPin(id: "birzebbuga",    coordinate: CLLocationCoordinate2D(latitude: 35.8222, longitude: 14.5250),
                      cameras: cams([214])),
            WebcamPin(id: "stgeorges",     coordinate: CLLocationCoordinate2D(latitude: 35.9206, longitude: 14.4878),
                      cameras: cams([5223])),
            WebcamPin(id: "golden-bay",    coordinate: CLLocationCoordinate2D(latitude: 35.9542, longitude: 14.3328),
                      cameras: cams([786])),
            WebcamPin(id: "cirkewwa",      coordinate: CLLocationCoordinate2D(latitude: 35.9863, longitude: 14.3334),
                      cameras: cams([755, 754, 626])),
            WebcamPin(id: "sliema",        coordinate: CLLocationCoordinate2D(latitude: 35.9063, longitude: 14.5039),
                      cameras: cams([356, 4455])),
            WebcamPin(id: "stpauls",       coordinate: CLLocationCoordinate2D(latitude: 35.9506, longitude: 14.4089),
                      cameras: cams([3372, 5304])),
            WebcamPin(id: "wied",          coordinate: CLLocationCoordinate2D(latitude: 35.8181, longitude: 14.4492),
                      cameras: cams([254])),
            WebcamPin(id: "marsalforn",    coordinate: CLLocationCoordinate2D(latitude: 36.0736, longitude: 14.2544),
                      cameras: cams([221])),
            WebcamPin(id: "mgarr",         coordinate: CLLocationCoordinate2D(latitude: 36.0194, longitude: 14.2983),
                      cameras: cams([864])),
        ]
    }()
}
