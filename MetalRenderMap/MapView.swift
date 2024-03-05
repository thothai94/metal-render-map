//
//  MapView.swift
//  MetalRenderMap
//
//  Created by Võ Toàn on 04/03/2024.
//

import SwiftUI
import UIKit
import MapLibre

struct MapView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CustomStyleLayerViewController {
        return CustomStyleLayerViewController()
    }

    func updateUIViewController(_ uiViewController: CustomStyleLayerViewController, context: Context) {
    }
}

final class CustomStyleLayerViewController: UIViewController, MLNMapViewDelegate {
    private var mapView: MLNMapView!
    private let modelOrigin = CLLocationCoordinate2DMake(10.785211, 106.693220)

    override func viewDidLoad() {
        super.viewDidLoad()

        setupMapView()
    }

    func setupMapView() {
        mapView = MLNMapView(frame: view.bounds)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.tintColor = .orange

        let camera = MLNMapCamera()
        mapView.setCamera(camera, animated: false)

        // Maplibre configuration
        mapView.styleURL = URL(string: "https://demotiles.maplibre.org/style.json")
        // restrict the zoom level
        mapView.maximumZoomLevel = 24.0
        mapView.zoomLevel = 12.0

        // restrict user interaction on the map
        mapView.allowsScrolling = true
        mapView.allowsRotating = true
        mapView.allowsTilting = true
        mapView.allowsZooming = true

        // disable built-in controls and user location
        mapView.displayHeadingCalibration = false
        mapView.showsUserLocation = true
        mapView.compassView.isHidden = false
        mapView.logoView.isHidden = false
        mapView.attributionButton.isHidden = false

        mapView.centerCoordinate = modelOrigin

        mapView.delegate = self

        view.addSubview(mapView)
    }

    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        print("finish loading style")
    }

    func mapViewDidFinishLoadingMap(_ mapView: MLNMapView) {
        print("finish loading map")

        if let mapStyle = mapView.style {
            let customLayer: CustomStyleLayer = CustomStyleLayer(identifier: "custom")
            mapStyle.addLayer(customLayer)
        }
    }
}
