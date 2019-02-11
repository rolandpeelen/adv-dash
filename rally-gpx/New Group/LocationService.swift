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
    let DOWNLOAD_OFFSET: Double = 7500; // minimal distance divided by two + overlap in meters
    
    public var initialized: Bool?;
    public var superView: UIView!;
    public var mapView: MGLMapView!
    private var progressView: UIProgressView!
    private var lastLocation: MGLUserLocation?;
    private var gpxService: GpxService!;
    private var helperService: HelperService!;
    static let sharedInstance: LocationService = {
        let instance = LocationService();
        return instance
    }()
        
    override init() {
        super.init();
        
        helperService = HelperService();
        
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
        mapView = MGLMapView(frame: superView.bounds, styleURL: MGLStyle.darkStyleURL)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.showsUserLocation = true
        superView.addSubview(mapView);
        mapView.delegate = self;
        
        MGLOfflineStorage.shared.reloadPacks()
        
        initialized = true;
        print("Roland: Mapview Initiated");
        
        return mapView;
    }
    
    
    func addTrack (notification:Notification) {
        let track = notification.userInfo!["track"] as! Array<CLLocationCoordinate2D>; // Fetch the track from the notification
        
        let polyLine = MGLPolyline(coordinates: track, count: UInt(track.count)) // Create a polyline from the points
        self.mapView.addAnnotation(polyLine) // Add the polyline to the view
        
        var boundingBoxes: Array<(CLLocationCoordinate2D, CLLocationCoordinate2D)> = [helperService.createBoundingBox(coordinate: track[0], offset: DOWNLOAD_OFFSET)];
        
//        startOfflinePackDownload(bounds: boundingBoxes[0], resolution: "HIRES", title: String(0));
        
        var points: Array<CLLocationCoordinate2D> = [track[0]]; // Start by adding the first point to the actual points
        var index:Int = 0;
        
        while(index < (track.count - 1)) {
            index = helperService.getFirstNewDistanceInMeters(baseIndex: index,
                                                              nextIndex: index + 1,
                                                              array: track,
                                                              MINIMAL_DISTANCE: MINIMAL_DISTANCE);
            points.append(track[index])
            
            let annotation = MGLPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: track[index].latitude, longitude: track[index].longitude)
            annotation.title = "\(index) MIDDLE"
            mapView.addAnnotation(annotation)
            
            let box = helperService.createBoundingBox(coordinate: track[index], offset: DOWNLOAD_OFFSET)
            boundingBoxes.append(box)
//            startOfflinePackDownload(bounds: box, resolution: "HIRES", title: String(index));
        }
        
        self.addBoundingBoxPolyLine(view: mapView!, boundingBoxes: boundingBoxes)
    }
    
    private func addBoundingBoxPolyLine(view: MGLMapView,
        boundingBoxes: Array<(CLLocationCoordinate2D, CLLocationCoordinate2D)>) {
        var swMarks: Array<(CLLocationCoordinate2D)> = []
        var neMarks: Array<(CLLocationCoordinate2D)> = []
        
        for (index, box) in boundingBoxes.enumerated() {
            let (SW, NE) = box;
            swMarks.append(SW);
            neMarks.append(NE);
            
            
//            let annotationSW = MGLPointAnnotation()
//            annotationSW.coordinate = CLLocationCoordinate2D(latitude: SW.latitude, longitude: SW.longitude)
//            annotationSW.title = "\(index) SW"
//            mapView.addAnnotation(annotationSW)
//
//            let annotationNE = MGLPointAnnotation()
//            annotationNE.coordinate = CLLocationCoordinate2D(latitude: NE.latitude, longitude: NE.longitude)
//            annotationNE.title = "\(index) NE"
//            mapView.addAnnotation(annotationNE)
        
            
            let boxLine = MGLPolyline(coordinates: [SW, NE], count: 2)
            self.mapView.addAnnotation(boxLine)
        }
        
        
        
//        let swLine = MGLPolyline(coordinates: swMarks, count: UInt(swMarks.count))
//        let neLine = MGLPolyline(coordinates: neMarks, count: UInt(neMarks.count))
//        self.mapView.addAnnotation(neLine)
//        self.mapView.addAnnotation(swLine)
    }

    func mapView(_ mapView: MGLMapView, didUpdate userLocation: MGLUserLocation?) {
        print("Roland: Updated Location");
        if(lastLocation == nil) { mapView.setCenter((userLocation?.coordinate)!,
                                                    zoomLevel: 10,
                                                    animated: false) }
        lastLocation = userLocation!;
//        mapView.userTrackingMode = MGLUserTrackingMode.followWithCourse
    }
    
    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        print("Roland: Finished Loading");
        /*
         As soon as the map is loaded, we can start fetching the resources. The gpxService is now configured
         to instantly load it's gpx file and give an async notification. This means we can only instantiate it here
        */
        gpxService = GpxService.sharedInstance;
        mapView.userTrackingMode = MGLUserTrackingMode.followWithCourse
    }
    
    func startOfflinePackDownload(bounds: (CLLocationCoordinate2D, CLLocationCoordinate2D), resolution: String, title: String) {
        /*
            Create a region that includes the current viewport and any tiles needed to view it when zoomed further in.
            Because tile count grows exponentially with the maximum zoom level, you should be conservative with your `toZoomLevel` setting.
         */
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
    func mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? { return nil }
    
    // Allow callout view to appear when an annotation is tapped.
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool { return true
    }
    
    /*
     Here are some helper functions to help out with loggins some shits. They should handle errors and do UI thingies,
        but ain't nobody got time for that.
     - The downloadCompleted will be seen as the progressbar dissappearing;
     */
    func downloadCompleted(byteCount: String, completed: UInt64) { print("Offline pack completed: \(byteCount), \(completed) resources") };
    func downloadProgress(completed: UInt64, total: UInt64, percentile: Float) { print("Offline pack has \(completed) of \(total) resources — \(percentile * 100)%.") };
    @objc func offlinePackDidReceiveError(notification: NSNotification) { print("Some offline shit received an error") }
    @objc func offlinePackDidReceiveMaximumAllowedMapboxTiles(notification: NSNotification) { print("Maximum tiles reached fam") }
    @objc func mapView(_ mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor { return UIColor.red }
    
    deinit { NotificationCenter.default.removeObserver(self) }
}
