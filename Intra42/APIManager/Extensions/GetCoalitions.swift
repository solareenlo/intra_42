//
//  GetCoalitions.swift
//  Intra42
//
//  Created by Felix Maury on 2019-05-25.
//  Copyright © 2019 Felix Maury. All rights reserved.
//

import Foundation
import SwiftyJSON

extension API42Manager {
    func getCoalitionInfo(forUserId id: Int, completionHandler: @escaping (String, UIColor?, String) -> Void) {
        request(url: "https://api.intra.42.fr/v2/users/\(id)/coalitions") { (responseJSON) in
            guard let data = responseJSON, data.isEmpty == false else {
                completionHandler("default", Colors.intraTeal, "")
                return
            }
            print(data)
            var lowestId = data.arrayValue[0]["id"].intValue
            var hexColor = ""
            var coaLogo = ""
            var coaSlug = ""
            
            for coalition in data.arrayValue {
                let id = coalition["id"].intValue
                if id <= lowestId {
                    lowestId = id
                    hexColor = coalition["color"].stringValue
                    coaLogo = coalition["image_url"].stringValue
                    coaSlug = coalition["slug"].stringValue.replacingOccurrences(of: "-", with: "_")
                    coaSlug = coaSlug.replacingOccurrences(of: "piscine_c_lyon_", with: "")
                }
            }
            
            completionHandler(coaSlug, UIColor(hexRGB: hexColor), coaLogo)
        }
    }
    
}
