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

class ViewController: UIViewController {
    var mapView: MGLMapView!
    var locationService: LocationService!;
    var lastLocation: MGLUserLocation?;

    override func viewDidLoad() {
        super.viewDidLoad()
        locationService = LocationService.sharedInstance;
        mapView = locationService.initMapView(view: view);
    }
}
