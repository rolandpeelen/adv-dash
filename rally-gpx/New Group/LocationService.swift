//
//  LocationService.swift
//  rally-gpx
//
//  Created by Roland Peelen on 1/12/19.
//  Copyright © 2019 Roland Peelen. All rights reserved.
//

import Foundation
import UIKit
import Mapbox
import CoreLocation

class LocationService: NSObject, MGLMapViewDelegate {
    // Options
    // This is used for the offline maps sizing, the minimal distance directly correlates to the surface area of the downloads in: SURFACE_AREA = MINIMAL_DISTANCE ^ 2 / 2;
    let MINIMAL_DISTANCE:Double = 5000;
    let HIGH_RES_OFFSET: Double = 10000; // minimal distance divided by two + overlap in meters
    let EARTH_RADIUS: Double = 6378137;
    
    public var initialized: Bool?;
    public var superView: UIView!;
    public var mapView: MGLMapView!
    private var progressView: UIProgressView!
    private var lastLocation: MGLUserLocation?;
    private var gpxService: GpxService!;
    static let sharedInstance: LocationService = {
        let instance = LocationService();
        return instance
    }()
        
    override init() {
        super.init();
        
        // Setup offline pack notification handlers.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(offlinePackProgressDidChange),
                                               name: NSNotification.Name.MGLOfflinePackProgressChanged, object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(offlinePackDidReceiveError),
                                               name: NSNotification.Name.MGLOfflinePackError, object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(offlinePackDidReceiveMaximumAllowedMapboxTiles),
                                               name: NSNotification.Name.MGLOfflinePackMaximumMapboxTilesReached, object: nil)
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "addTrack"),
                                               object: nil,
                                               queue: nil,
                                               using:addTrack)
    }
    
    func initMapView(view: UIView) -> MGLMapView {
        superView = view;
        mapView = MGLMapView(frame: superView.bounds, styleURL: MGLStyle.outdoorsStyleURL)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.showsUserLocation = true
        superView.addSubview(mapView);
        mapView.delegate = self;
    
//        MGLOfflineStorage.shared.reloadPacks()
        
        initialized = true;
        print("Roland: Mapview Initiated");
        
        return mapView;
    }
    
    func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let to = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return from.distance(from: to)
    }
    
    // first new distance
    func getFirstNewDistanceInMeters(baseIndex: Int, nextIndex: Int, array: Array<CLLocationCoordinate2D>) -> Int {
        if(nextIndex >= array.count) {return array.count - 1}; // if we've reached the end of the array, return the second to last object
        let distanceAB = distance(from: array[baseIndex], to: array[nextIndex]); // get the distance between the two points
        
        // if the distance is bigger or equal to the minimal distance, return it. Otherwise, up the index of point B with one and return this function
        return distanceAB >= MINIMAL_DISTANCE ? nextIndex : getFirstNewDistanceInMeters(baseIndex: baseIndex, nextIndex: 1 + nextIndex, array: array);
    }
    
    func createBoundingBox(coordinate: CLLocationCoordinate2D, offset: Double) -> (CLLocationCoordinate2D, CLLocationCoordinate2D) {
        let differenceLat = (offset / EARTH_RADIUS) * 180 / Double.pi;
        let differenceLong = (offset / (EARTH_RADIUS * cos(Double.pi * coordinate.latitude / 180))) * 180 / Double.pi;
        let SW = CLLocationCoordinate2DMake(coordinate.latitude - differenceLat, coordinate.longitude - differenceLong)
        let NE = CLLocationCoordinate2DMake(coordinate.latitude + differenceLat, coordinate.longitude + differenceLong)
        return (SW, NE);
    }
    
    func addTrack (notification:Notification) {
        let track = notification.userInfo!["track"] as! Array<CLLocationCoordinate2D>; // set the track
        
        var points: Array<CLLocationCoordinate2D> = [track[0]]; // Start by adding the first point to the actual points
        
        let polyLine = MGLPolyline(coordinates: track, count: UInt(track.count))
        self.mapView.addAnnotation(polyLine)
        
        var highResBoxes: Array<(CLLocationCoordinate2D, CLLocationCoordinate2D)> = [createBoundingBox(coordinate: track[0], offset: HIGH_RES_OFFSET)];
        startOfflinePackDownload(bounds: highResBoxes[0], resolution: "HIRES", title: String(0));
        
        var index:Int = 0;
        while(index < (track.count - 1)) {
            index = getFirstNewDistanceInMeters(baseIndex: index, nextIndex: index + 1, array: track); // get the first next distance
            points.append(track[index]) // and append that to the points
            
            let highResBox = createBoundingBox(coordinate: track[index], offset: HIGH_RES_OFFSET)
            highResBoxes.append(highResBox)
            startOfflinePackDownload(bounds: highResBox, resolution: "HIRES", title: String(index));
        }
        
        var swMarks: Array<(CLLocationCoordinate2D)> = []
        var neMarks: Array<(CLLocationCoordinate2D)> = []
        
        for (_, box) in highResBoxes.enumerated() {
            let (SW, NE) = box;
            swMarks.append(SW);
            neMarks.append(NE);
            let annotationSW = MGLPointAnnotation()
            annotationSW.coordinate = CLLocationCoordinate2D(latitude: SW.latitude, longitude: SW.longitude)
            annotationSW.title = "HIGHRES SW"
            mapView.addAnnotation(annotationSW)

            let annotationNE = MGLPointAnnotation()
            annotationNE.coordinate = CLLocationCoordinate2D(latitude: NE.latitude, longitude: NE.longitude)
            annotationNE.title = "HIGHRES NE"
            mapView.addAnnotation(annotationNE)
        }
        
        let swLine = MGLPolyline(coordinates: swMarks, count: UInt(swMarks.count))
        self.mapView.addAnnotation(swLine)
        
        let neLine = MGLPolyline(coordinates: neMarks, count: UInt(neMarks.count))
        self.mapView.addAnnotation(neLine)
    }

    func mapView(_ mapView: MGLMapView, didUpdate userLocation: MGLUserLocation?) {
        print("Roland: Updated Location");
        if(lastLocation == nil) { mapView.setCenter((userLocation?.coordinate)!,
                                                    zoomLevel: 10,
                                                    animated: false) }
        lastLocation = userLocation!;
        mapView.userTrackingMode = MGLUserTrackingMode.followWithCourse
    }
    
    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        // Start downloading tiles and resources for z13-16.
        print("Roland: Finished Loading");
        gpxService = GpxService.sharedInstance;
        mapView.userTrackingMode = MGLUserTrackingMode.followWithCourse
    }
    
    func startOfflinePackDownload(bounds: (CLLocationCoordinate2D, CLLocationCoordinate2D), resolution: String, title: String) {
        // Create a region that includes the current viewport and any tiles needed to view it when zoomed further in.
        // Because tile count grows exponentially with the maximum zoom level, you should be conservative with your `toZoomLevel` setting.
        let fromZoomLevel: Double = resolution == "HIRES" ? 8 : 8;
        let toZoomLevel: Double = resolution == "HIRES" ? 14 : 10;
        let (SW, NE) = bounds;
        let bounds = MGLCoordinateBounds.init(sw: SW, ne: NE);
        do {
            let region = MGLTilePyramidOfflineRegion(styleURL: mapView.styleURL,
                                                     bounds: bounds,
                                                     fromZoomLevel: fromZoomLevel,
                                                     toZoomLevel: toZoomLevel)
            let storageObject = [title: "\(SW), \(NE)"]
            let storageArchive = try NSKeyedArchiver.archivedData(withRootObject: storageObject,
                                                                  requiringSecureCoding: false)
            MGLOfflineStorage.shared.addPack(for: region,
                                             withContext: storageArchive) {
                                                (pack, error) in guard error == nil else {
                                                    // The pack couldn’t be created for some reason.
                                                    print("Error: \(error?.localizedDescription ?? "unknown error")")
                                                    return
                                                }
                                                pack!.resume()
            }
        }
        catch {
            print(error)
        }
    }
    
    @objc func offlinePackProgressDidChange(notification: NSNotification) {
        let download = notification.object as? MGLOfflinePack;
        if (download == nil) {return};
        
        let progress = download!.progress // as we check if pack is nil, we can now safely assume we have it here.
        let completed = progress.countOfResourcesCompleted
        let total = progress.countOfResourcesExpected
        let progressPercentile = Float(completed) / Float(total)
        
        // Setup the progress bar.
        if (progressView == nil) {
            progressView = UIProgressView(progressViewStyle: .default)
            let frame = superView.bounds.size
            progressView.frame = CGRect(x: frame.width / 4, y: frame.height * 0.75, width: frame.width / 2, height: 10)
            superView.addSubview(progressView)
        }
        progressView.progress = progressPercentile
        
        // If this pack has finished, print its size and resource count.
        if (completed == total) {
            let byteCount = ByteCountFormatter.string(
                fromByteCount: Int64(download!.progress.countOfBytesCompleted),
                countStyle: ByteCountFormatter.CountStyle.memory)
            
            progressView.removeFromSuperview()
            return downloadCompleted(byteCount: byteCount, completed: completed);
        }
        
        downloadProgress(completed: completed, total: total, percentile: progressPercentile);
    }
    
    // Use the default marker. See also: our view annotation or custom marker examples.
    func mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? {
        return nil
    }
    
    // Allow callout view to appear when an annotation is tapped.
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
    
    // Here are some helper functions to help out with loggins some shits
    func downloadCompleted(byteCount: String, completed: UInt64) { print("Offline pack completed: \(byteCount), \(completed) resources") };
    func downloadProgress(completed: UInt64, total: UInt64, percentile: Float) { print("Offline pack has \(completed) of \(total) resources — \(percentile * 100)%.") };
    @objc func offlinePackDidReceiveError(notification: NSNotification) { print("Some offline shit received an error") }
    @objc func offlinePackDidReceiveMaximumAllowedMapboxTiles(notification: NSNotification) { print("Maximum tiles reached fam") }
    @objc func mapView(_ mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor { return UIColor.red }
    
    deinit { NotificationCenter.default.removeObserver(self) }
}
