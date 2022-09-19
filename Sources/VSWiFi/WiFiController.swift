//
//  WiFiController.swift
//  
//
//  Created by Théodore Roos on 2022-09-01.
//

import Combine
import Foundation
import NetworkExtension
import VSFoundation

public class WiFiController: IWiFiController {
  public private(set) var wifiInfoPublisher: CurrentValueSubject<WiFiInfo?, WiFiError> = .init(nil)
  public private(set) var timeInterval = 0.5

  public private(set) var hotspotManager = NEHotspotConfigurationManager.shared
  private var fetchingWiFiInfoTimer: Timer?

  public init() {
    startTimer()
  }

  public func add(ssid: String, passphrase: String, isWEP: Bool, completion: ((Error?) -> Void)? = nil) {
    hotspotManager.apply(NEHotspotConfiguration(ssid: ssid, passphrase: passphrase, isWEP: isWEP), completionHandler: completion)
  }

  public func add(ssid: String, completion: ((Error?) -> Void)? = nil) {
    hotspotManager.apply(NEHotspotConfiguration(ssid: ssid), completionHandler: completion)
  }

  public func getConfiguredSSIDs() -> [String] {
    var arr = [String]()
    hotspotManager.getConfiguredSSIDs { arr = $0 }
    return arr
  }

  var currentBSSID: String = ""
  var latestChange = Date()
  public func fetch(completion: @escaping (WiFiInfo) -> Void) {
    NEHotspotNetwork.fetchCurrent { (network) in
      guard
        let bssid = network?.bssid,
        let ssid = network?.ssid,
        let signalStrength = network?.signalStrength
      else { return }

      if self.currentBSSID != bssid {
        self.currentBSSID = bssid
        self.latestChange = Date()
      } else if Date().timeIntervalSince(self.latestChange) > 5 {
        completion(WiFiInfo(bssid: bssid, ssid: ssid, signalStrength: signalStrength))
      }
    }
  }

  public func set(timeInterval: Double) {
    self.timeInterval = timeInterval
    startTimer()
  }

  private func startTimer() {
    fetchingWiFiInfoTimer?.invalidate()
    fetchingWiFiInfoTimer = nil
    fetchingWiFiInfoTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true, block: { (_) in
      self.fetch { (info) in
        self.wifiInfoPublisher.send(WiFiInfo(bssid: info.bssid, ssid: info.ssid, signalStrength: info.signalStrength))
      }
    })
  }
}
