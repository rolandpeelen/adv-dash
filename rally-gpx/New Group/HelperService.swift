//
//  HelperService.swift
//  rally-gpx
//
//  Created by roland peelen on 08/02/2019.
//  Copyright © 2019 Roland Peelen. All rights reserved.
//

import Foundation
import Mapbox

class HelperService: NSObject {
    private let EARTH_RADIUS: Double = 6378137;
    
    /*
     Essentially a functional wrapper for the CLLocationCoordinate.distance
     The original one is on the CLLocation object
     */
    func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let to = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return from.distance(from: to)
    }
    
    /*
     This function returns the next index that is of minimal distance to the base index.
     If the last object is reachted, it returns that.
     If not, and the distance is bigger or equal to the minimal distance, return that index.
     Otherwise, up the index of point B with one and return this function
     */
    func getFirstNewDistanceInMeters(baseIndex: Int,
                                     nextIndex: Int,
                                     array: Array<CLLocationCoordinate2D>,
                                     MINIMAL_DISTANCE: Double) -> Int {
        if(baseIndex == 0) {return 1};
        if(nextIndex >= array.count) {return array.count - 1};
        let distanceAB = distance(from: array[baseIndex], to: array[nextIndex]);
        return distanceAB >= MINIMAL_DISTANCE ? nextIndex : getFirstNewDistanceInMeters(baseIndex: baseIndex, nextIndex: 1 + nextIndex, array: array, MINIMAL_DISTANCE: MINIMAL_DISTANCE);
    }
    
    /*
     Create a boundingbox with minimum offsets around a CLLocationCoordinate, but done properly with earth
     latitude and longitude in mind
     */
    func createBoundingBoxAllCoordinates(coordinate: CLLocationCoordinate2D, offset: Double) -> (CLLocationCoordinate2D, CLLocationCoordinate2D, CLLocationCoordinate2D, CLLocationCoordinate2D) {
        let differenceLat = (offset / EARTH_RADIUS) * 180 / Double.pi;
        let differenceLong = (offset / (EARTH_RADIUS * cos(Double.pi * coordinate.latitude / 180))) * 180 / Double.pi;
        let NW = CLLocationCoordinate2DMake(coordinate.latitude - differenceLat, coordinate.longitude + differenceLong)
        let NE = CLLocationCoordinate2DMake(coordinate.latitude + differenceLat, coordinate.longitude + differenceLong)
        let SW = CLLocationCoordinate2DMake(coordinate.latitude - differenceLat, coordinate.longitude - differenceLong)
        let SE = CLLocationCoordinate2DMake(coordinate.latitude + differenceLat, coordinate.longitude - differenceLong)
        return (NW, NE, SW, SE)
    }

    
}
