//
//  ViewController.swift
//  rally-gpx
//
//  Created by Roland Peelen on 12/30/18.
//  Copyright © 2018 Roland Peelen. All rights reserved.
//

import UIKit
import Mapbox
import CoreLocation

class ViewController: UIViewController, MGLMapViewDelegate {
    var mapView: MGLMapView!
    var progressView: UIProgressView!
    var lastLocation: MGLUserLocation?;

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // Setup Mapbox stuff
        mapView = MGLMapView(frame: view.bounds, styleURL: MGLStyle.darkStyleURL)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            mapView.delegate = self
        mapView.showsUserLocation = true
        view.addSubview(mapView)
        
        // Setup offline pack notification handlers.
        NotificationCenter.default.addObserver(self, selector: #selector(offlinePackProgressDidChange), name: NSNotification.Name.MGLOfflinePackProgressChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(offlinePackDidReceiveError), name: NSNotification.Name.MGLOfflinePackError, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(offlinePackDidReceiveMaximumAllowedMapboxTiles), name: NSNotification.Name.MGLOfflinePackMaximumMapboxTilesReached, object: nil)
    }
    
    func mapView(_ mapView: MGLMapView, didUpdate userLocation: MGLUserLocation?) {
        if(lastLocation == nil) {
            mapView.setCenter((userLocation?.coordinate)!, zoomLevel: 11, animated: false)
        }
        lastLocation = userLocation!;
    }
    
    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        // Start downloading tiles and resources for z13-16.
        startOfflinePackDownload()
        mapView.userTrackingMode = MGLUserTrackingMode.followWithCourse
    }
    
    deinit {
        // Remove offline pack observers.
        NotificationCenter.default.removeObserver(self)
    }
    
    func startOfflinePackDownload() {
        // Create a region that includes the current viewport and any tiles needed to view it when zoomed further in.
        // Because tile count grows exponentially with the maximum zoom level, you should be conservative with your `toZoomLevel` setting.
        do {
            let region = MGLTilePyramidOfflineRegion(styleURL: mapView.styleURL, bounds: mapView.visibleCoordinateBounds, fromZoomLevel: mapView.zoomLevel, toZoomLevel: 15)
            
            // Store some data for identification purposes alongside the downloaded resources.
            let userInfo = ["name": "My Offline Pack"]
            let context = try NSKeyedArchiver.archivedData(withRootObject: userInfo, requiringSecureCoding: false)
            
            // Create and register an offline pack with the shared offline storage object.
            
            MGLOfflineStorage.shared.addPack(for: region, withContext: context) { (pack, error) in
                guard error == nil else {
                    // The pack couldn’t be created for some reason.
                    print("Error: \(error?.localizedDescription ?? "unknown error")")
                    return
                }
                
                // Start downloading.
                pack!.resume()
            }
        }
        catch {
            print(error)
        }
        
        
    }
    
    // MARK: - MGLOfflinePack notification handlers
    @objc func offlinePackProgressDidChange(notification: NSNotification) {
        
        let download = notification.object as? MGLOfflinePack;
        if (download == nil) {return};
        
        let progress = download!.progress // as we check if pack is nil, we can now safely assume we have it here.
        let completed = progress.countOfResourcesCompleted
        let total = progress.countOfResourcesExpected
        let progressPercentile = Float(completed) / Float(total)
        
        // Setup the progress bar.
        if (progressView == nil) {
            let progressView = createProgressView(view: view);
            view.addSubview(progressView)
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
    
    func createProgressView(view: UIView) -> UIView {
        progressView = UIProgressView(progressViewStyle: .default)
        let frame = view.bounds.size
        progressView.frame = CGRect(x: frame.width / 4, y: frame.height * 0.75, width: frame.width / 2, height: 10)
        return progressView;
    }
    func downloadCompleted(byteCount: String, completed: UInt64) { print("Offline pack completed: \(byteCount), \(completed) resources") };
    func downloadProgress(completed: UInt64, total: UInt64, percentile: Float) { print("Offline pack has \(completed) of \(total) resources — \(progressPercentile * 100)%.") };
    
    
    @objc func offlinePackDidReceiveError(notification: NSNotification) {
        print("Some offline shit received an error")
//        if let pack = notification.object as? MGLOfflinePack,
//            let userInfo = NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(pack.context) as? [String: String],
//            let error = notification.userInfo?[MGLOfflinePackUserInfoKey.error] as? NSError {
//            print("Offline pack “\(userInfo["name"] ?? "unknown")” received error: \(error.localizedFailureReason ?? "unknown error")")
//        }
    }
    
    @objc func offlinePackDidReceiveMaximumAllowedMapboxTiles(notification: NSNotification) {
        print("Maximum tiles reached fam")
//        if let pack = notification.object as? MGLOfflinePack,
//            let userInfo = NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(pack.context) as? [String: String],
//            let maximumCount = (notification.userInfo?[MGLOfflinePackUserInfoKey.maximumCount] as AnyObject).uint64Value {
//            print("Offline pack “\(userInfo["name"] ?? "unknown")” reached limit of \(maximumCount) tiles.")
//        }
    }
}

