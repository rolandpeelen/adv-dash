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
    /*
     OPTIONS
     This is used for the offline maps sizing, the minimal distance directly correlates to the surface area of the downloads in: SURFACE_AREA = MINIMAL_DISTANCE ^ 2 / 2;
     */
    let KEEP_TRACK_OF_LOCATION:Bool = false;
    let VISUAL_DEBUGGING:Bool = true;
    let OFFLINE_MODE:Bool = true;
    let MINIMAL_DISTANCE:Double = 5000;
    let DOWNLOAD_OFFSET: Double = 1000;
    
    /*
     PUBLIC
    */
    public var initialized: Bool?;
    public var superView: UIView!;
    public var mapView: MGLMapView!
    static let sharedInstance: LocationService = {
        let instance = LocationService();
        return instance
    }()
    
    /*
     PRIVATE
     */
    private var downloadStatus: Array<(String, UInt64, UInt64)> = [];
    private var progressView: UIProgressView!
    private var lastLocation: MGLUserLocation?;
    private var gpxService: GpxService!;
    private var helperService: HelperService!;
    
        
    override init() {
        super.init();
        
        helperService = HelperService();
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
        
//        MGLOfflineStorage.shared.reloadPacks()
        
        initialized = true;
        print("Roland: Mapview Initiated");
        
        return mapView;
    }
    
    
    func addTrack (notification:Notification) {
        let track = notification.userInfo!["track"] as! Array<CLLocationCoordinate2D>;
        
        let polyLine = MGLPolyline(coordinates: track, count: UInt(track.count))
        self.mapView.addAnnotation(polyLine)
        
        var index:Int = 0;
        var offlineBoxes: Array<(Int, CLLocationCoordinate2D, CLLocationCoordinate2D)> = [];
        while(index < (track.count - 1)) {
            index = helperService.getFirstNewDistanceInMeters(baseIndex: index,
                                                              nextIndex: index + 1,
                                                              array: track,
                                                              MINIMAL_DISTANCE: MINIMAL_DISTANCE);
            let (SW, NE, SE, NW) = helperService.createBoundingBoxAllCoordinates(coordinate: track[index], offset: DOWNLOAD_OFFSET)

            if(OFFLINE_MODE) { offlineBoxes.append((index, SW, NE));}
            if(VISUAL_DEBUGGING){ self.mapView.addAnnotation(MGLPolyline(coordinates: [NW, NE, SW, SE, NW], count: 5)) }
        }
        startOfflinePackDownload(boxes: offlineBoxes)
    }

    func mapView(_ mapView: MGLMapView, didUpdate userLocation: MGLUserLocation?) {
        print("Roland: Updated Location");
        if(lastLocation == nil) { mapView.setCenter((userLocation?.coordinate)!,
                                                    zoomLevel: 12,
                                                    animated: false) }
        lastLocation = userLocation!;
        
        if(KEEP_TRACK_OF_LOCATION) { mapView.userTrackingMode = MGLUserTrackingMode.followWithCourse; }
    }
    
    /*
     As soon as the map is loaded, we can start fetching the resources. The gpxService is configured
     to instantly load it's gpx file and give an async notification. This means we can only instantiate it here after the mapview
     is finished loading.
     */
    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        print("Roland: Finished Loading");
        
        gpxService = GpxService.sharedInstance;
        mapView.userTrackingMode = MGLUserTrackingMode.followWithCourse
    }
    
    /*
     Create a region that includes the current viewport and any tiles needed to view it when zoomed further in.
     Because tile count grows exponentially with the maximum zoom level, you should be conservative with your `toZoomLevel` setting.
     
     This function takes some bounds which are in the form of a (SW, NE) tuple. For debugging, keeping full bounding boxes for everything
     up until this point is nicer because we can draw the bounding boxes to see how much they overlap and fine tune the results a lot better.
     While a bit less performant, this should work just fine :)
     */
    func startOfflinePackDownload(boxes: Array<(Int, CLLocationCoordinate2D, CLLocationCoordinate2D)>) {
        for (index, SW, NE) in boxes {
            let fromZoomLevel: Double = 8;
            let toZoomLevel: Double = 10; // This should become 14 again
            let bounds = MGLCoordinateBounds.init(sw: SW, ne: NE);
            do {
                let storageObject = [index: "\(SW), \(NE)"]
                let region = MGLTilePyramidOfflineRegion(styleURL: mapView.styleURL,
                                                         bounds: bounds,
                                                         fromZoomLevel: fromZoomLevel,
                                                         toZoomLevel: toZoomLevel)
                let storageArchive = try NSKeyedArchiver.archivedData(withRootObject: storageObject,
                                                                      requiringSecureCoding: false)
                
                MGLOfflineStorage.shared.addPack(for: region,
                                                 withContext: storageArchive) {
                                                    (pack, error) in guard error == nil else { return print("Error: \(error?.localizedDescription ?? "unknown error")") }
                                                    pack!.resume()
                }
            }
            catch {
                print(error)
            }
        }
    }

    /*
     The offlinePacks all need to be tracked together otherwise we can't realistically show progress. Ass such, we're stringifying them and appending them
     to the array
     */
    @objc func offlinePackProgressDidChange(notification: NSNotification) {
        let download = notification.object as? MGLOfflinePack;
        if (download == nil) {return};
        let progress = download!.progress
        let completed = progress.countOfResourcesCompleted
        let total = progress.countOfResourcesExpected
        
        let stringifiedRegion = "\(download!.region)"
        let newContext = (stringifiedRegion, total, completed);
        downloadStatus = downloadStatus.filter { $0.0 != stringifiedRegion };
        downloadStatus.append(newContext)
        
        updateProgress();
    }
    
    func updateProgress() {
        if (progressView == nil) {
            progressView = UIProgressView(progressViewStyle: .default)
            let frame = superView.bounds.size
            progressView.frame = CGRect(x: frame.width / 4, y: frame.height * 0.75, width: frame.width / 2, height: 10)
            superView.addSubview(progressView)
        }
        let total: UInt64 = downloadStatus.reduce(0) {result, context in result + context.1};
        let completed: UInt64 = downloadStatus.reduce(0) {result, context in result + context.2};
        let progressPercentile = Float(completed) / Float(total);
        progressView.progress = progressPercentile
        print("Total: \(total), Completed: \(completed)");
        if (completed == total) {
            progressView.removeFromSuperview()
            return print("Downloading Complete")
        }
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
    @objc func offlinePackDidReceiveError(notification: NSNotification) { print("Some offline shit received an error") }
    @objc func offlinePackDidReceiveMaximumAllowedMapboxTiles(notification: NSNotification) { print("Maximum tiles reached fam") }
    @objc func mapView(_ mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor { return UIColor.red }
    
    deinit { NotificationCenter.default.removeObserver(self) }
}
