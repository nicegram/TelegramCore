//
//  AskUrl.swift
//  TelegramCore
//
//  Created by Sergey Ak on 5/7/19.
//  Copyright © 2019 Nicegram. All rights reserved.
//

import Foundation
// POSTBOX STORAGE
import Postbox
import SwiftSignalKit
import MtProtoKitDynamic

public struct AskUrlSettings: PostboxCoding, Equatable, Hashable {
    public let url: String
    
    public init(url: String) {
        self.url = url
    }
    
    public init(decoder: PostboxDecoder) {
        self.url = decoder.decodeStringForKey("url", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.url, forKey: "url")
    }
}
