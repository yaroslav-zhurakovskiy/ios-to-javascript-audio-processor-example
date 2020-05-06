//
//  ByteArrray.swift
//  AudioRecorder
//
//  Created by Yaroslav Zhurakovskiy on 06.05.2020.
//  Copyright © 2020 Yaroslav Zhurakovskiy. All rights reserved.
//

import JavaScriptCore

@objc protocol ByteArrayJSExport: JSExport {
    var length: Int { get }
    
    func getByte(_ index: Int) -> UInt8
}

class ByteArray: NSObject, ByteArrayJSExport {
    private let data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    dynamic var length: Int {
        return data.count
    }
    
    dynamic func getByte(_ index: Int) -> UInt8 {
        return data[index]
    }
}
