//
//  GpxService.swift
//  rally-gpx
//
//  Created by Roland Peelen on 1/13/19.
//  Copyright © 2019 Roland Peelen. All rights reserved.
//

import Foundation
import CoreLocation

class GpxService: NSObject, XMLParserDelegate {
    private var loadedFiles: Array<NSObject> = [];
    private var parsedFiles: Array<NSObject> = [];
    private var track: Array<CLLocationCoordinate2D> = [];
    
    static let sharedInstance: GpxService = {
        let instance = GpxService();
        return instance
    }()
    
    override init() {
        super.init();
        loadFile();
    }
    
    func loadFile() {
        let gpxPath = Bundle.main.path(forResource: "test", ofType: "gpx")
        let gpxData = NSData(contentsOfFile: gpxPath ?? "")
        let parser = XMLParser(data: gpxData! as Data);
        parser.delegate = self;
        parser.parse();
    }
    
    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String : String]) {
        // If the parser encounters a 'trk' at didStartElement, it means there is a new track in the file
        if(elementName == "trk"){ track = [] };
        // These are the waypoints for the tracks
        if elementName == "trkpt" || elementName == "wpt" {
            //Create a World map coordinate from the file
            let lat = attributeDict["lat"]!
            let lon = attributeDict["lon"]!
            track.append(CLLocationCoordinate2DMake(CLLocationDegrees(lat)!, CLLocationDegrees(lon)!))
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        // If the parser encounters a 'trk' at didEndElement, it means the track is finished
        if(elementName == "trk"){
            print("Roland: Track loading finished")
            NotificationCenter.default.post(name: Notification.Name(rawValue: "addTrack"), object: nil, userInfo: ["track": track]);
        }
    }
}
