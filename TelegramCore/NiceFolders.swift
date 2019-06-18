//
//  NiceFolders.swift
//  TelegramCore
//
//  Created by Sergey AK on 6/15/19.
//  Copyright © 2019 Nicegram. All rights reserved.
//

import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKitDynamic

public func generateFolderGroupId() -> PeerGroupId {
    var id: Int32 = 0
    while true {
        arc4random_buf(&id, 4)
        let res = PeerGroupId(rawValue: abs(id))
        if isNiceFolderCheck(groupId: res) {
            return res
        }
    }
}

public struct NiceFolder: PostboxCoding, Equatable, Hashable {
    public var name: String
    public var groupId: PeerGroupId
    public var items: [Int64]
    
    public init(name: String, groupId: PeerGroupId, items: [Int64]) {
        self.name = name
        self.groupId = groupId
        self.items = items
    }
    
    public init(decoder: PostboxDecoder) {
        self.name = decoder.decodeStringForKey("nice:folder:name", orElse: "Folder")
        self.groupId = PeerGroupId(rawValue: decoder.decodeInt32ForKey("nice:folder:groupId", orElse: 2405))
        self.items = decoder.decodeInt64ArrayForKey("nice:folder:items")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.name, forKey: "nice:folder:name")
        encoder.encodeInt32(self.groupId.rawValue, forKey: "nice:folder:groupId")
        encoder.encodeInt64Array(self.items, forKey: "nice:folder:items")
    }
}


public struct NiceFolders: PreferencesEntry, Equatable {
    public var folders: [NiceFolder]
    
    public static var defaultSettings: NiceFolders {
        return NiceFolders(folders: [])
    }
    
    public init(folders: [NiceFolder]) {
        self.folders = folders
    }
    
    public init(decoder: PostboxDecoder) {
        self.folders = decoder.decodeObjectArrayWithDecoderForKey("nice:folders") // [NiceFolder(decoder: decoder)]
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.folders, forKey: "nice:folders")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? NiceFolders else {
            return false
        }
        
        return self == to
    }
}

public func updateNiceFoldersInteractively(accountManager: AccountManager, _ f: @escaping (NiceFolders) -> NiceFolders) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        updateNiceFoldersInteractively(transaction: transaction, f)
    }
}


public func updateNiceFoldersInteractively(transaction: AccountManagerModifier, _ f: @escaping (NiceFolders) -> NiceFolders) {
    transaction.updateSharedData(SharedDataKeys.niceFolders, { current in
        let previous = (current as? NiceFolders) ?? NiceFolders.defaultSettings
        let updated = f(previous)
        return updated
    })
}


public func createNiceFolder(accountManager: AccountManager, name: String?, peerIds: [PeerId], groupId: PeerGroupId? = nil) {
    var groupId = groupId
    // let semaphore = DispatchSemaphore(value: 0)
    let _ = updateNiceFoldersInteractively(accountManager: accountManager, { settings in
        var folder: NiceFolder
        var settings = settings
        
        if (groupId == nil) {
            groupId = generateFolderGroupId()
        }
        Logger.shared.log("NiceFolders", "Creating Folder \(groupId!.rawValue) \(name ?? "")")
        var items: [Int64] = []
        for peer in peerIds {
            items.append(peer.toInt64())
        }
        folder = NiceFolder(name: name ?? "F. \(groupId!.rawValue)", groupId: groupId!, items: items)
        settings.folders.append(folder)
        // semaphore.signal()
        return settings
    }).start()
    // semaphore.wait()
}


public func deleteNiceFolder(accountManager: AccountManager, groupId: PeerGroupId) {
    let _ = (updateNiceFoldersInteractively(accountManager: accountManager, { settings in
        var settings = settings
        Logger.shared.log("NiceFolders", "Deleting Folder \(groupId.rawValue)")
        for (index, folder) in settings.folders.enumerated() {
            if folder.groupId == groupId {
                // TODO: remove peerIds
                Logger.shared.log("NiceFolders", "Succesfully Deleted Folder \(groupId.rawValue)")
                settings.folders.remove(at: index)
                break
            }
        }
        return settings
    }) |> deliverOnMainQueue).start()
}

public func getNiceFoldersInteractively(accountManager: AccountManager) -> Signal<NiceFolders, NoError> {
    return accountManager.transaction { transaction -> NiceFolders in
        getNiceFoldersInteractively(transaction: transaction)
    }
}


public func getNiceFoldersInteractively(transaction: AccountManagerModifier) -> NiceFolders {
    let niceFolders: NiceFolders
    if let current = transaction.getSharedData(SharedDataKeys.niceFolders) as? NiceFolders {
        niceFolders = current
    } else {
        niceFolders = NiceFolders.defaultSettings
    }
    
    return niceFolders
}


public func getNiceFolders(accountManager: AccountManager) -> NiceFolders {
    var niceFolders: NiceFolders? = nil
    let semaphore = DispatchSemaphore(value: 0)
    _ = (accountManager.transaction { transaction in
        niceFolders = transaction.getSharedData(SharedDataKeys.niceFolders) as? NiceFolders
        semaphore.signal()
    }).start()
    semaphore.wait()
    
    if (niceFolders == nil) {
        niceFolders = NiceFolders.defaultSettings
    }
    
    Logger.shared.log("NiceFolders", "Searching Folders \(String(describing: niceFolders))")
    
    return niceFolders!
}

public func getNiceFolder(accountManager: AccountManager, groupId: PeerGroupId) -> NiceFolder? {
    var niceFolders: NiceFolders? = nil
    var niceFolder: NiceFolder? = nil
    
    niceFolders = getNiceFolders(accountManager: accountManager)
    
    for folder in niceFolders!.folders {
        if folder.groupId == groupId {
            niceFolder = folder
            break
        }
    }
    
    return niceFolder
}

public func isNiceFolderCheck(groupId: PeerGroupId) -> Bool {
    let tgGroups: [Int32] = [0, 1]
    var isNFolder = false
    
    /*let groups = Namespaces.PeerGroup()
    let mirror = Mirror(reflecting: groups)
    for child in mirror.children  {
        tgGroups.append((child.value as! PeerGroupId).rawValue)
    }*/
    
    if !tgGroups.contains(groupId.rawValue) {
        isNFolder = true
    }
    
    return isNFolder
}


public func resetNiceFolders(accountManager: AccountManager) {
    /*let _ = updateNiceFoldersInteractively(accountManager: accountManager, { settings in
        var settings = settings
        settings.folders = []
        // semaphore.signal()
        return settings
    }).start()*/
    
    let niceFolders = getNiceFolders(accountManager: accountManager)
    
    let semaphore = DispatchSemaphore(value: 0)
    _ = (accountManager.transaction { transaction in
        // Clearing database
        transaction.updateSharedData(SharedDataKeys.niceFolders, { _ in
            return NiceFolders.defaultSettings
        })
        
        semaphore.signal()
    }).start()
    semaphore.wait()

    /*
    // Clearing inclusions
    for folder in niceFolders.folders {
        for item in folder.items {
            //let semaphore2 = DispatchSemaphore(value: 0)
            let _ = postbox.transaction { transaction -> Void in
                transaction.updatePeerChatListInclusion(PeerId(item), inclusion: .notIncluded)
                //semaphore2.signal()
            }
            //semaphore2.wait()
        }
    }
    */

}

public func removeNiceFolderItems(accountManager: AccountManager, groupId: PeerGroupId, peerIds: [PeerId]) {
    if let _ = getNiceFolder(accountManager: accountManager, groupId: groupId) {
        var niceFolders = getNiceFolders(accountManager: accountManager)
        
        let semaphore = DispatchSemaphore(value: 0)
        _ = (accountManager.transaction { transaction in
            transaction.updateSharedData(SharedDataKeys.niceFolders, { current in
                for (findex, folder) in niceFolders.folders.enumerated() {
                    // Find folder
                    if folder.groupId == groupId {
                        // Convert peers to int
                        var peersToRemove: [Int64] = []
                        for peerId in peerIds {
                            peersToRemove.append(peerId.toInt64())
                        }
                        print("Removing from \(groupId.rawValue) items: \(peersToRemove))")
                        Logger.shared.log("NiceFolders", "Removing from \(groupId.rawValue) items: \(peersToRemove))")
                        
                        // Generate final items list
                        let newFolderItems = Array(Set(folder.items).subtracting(peersToRemove))
                        
                        // Set new folder items
                        niceFolders.folders[findex].items = newFolderItems
                        
                        // Stop
                        break
                    }
                }
                
                return niceFolders
            })
            semaphore.signal()
        }).start()
        semaphore.wait()
        /*
        let _ = updateNiceFoldersInteractively(accountManager: accountManager, { settings in
            var settings = settings
            for (findex, folder) in settings.folders.enumerated() {
                // Find folder
                if folder.groupId == groupId {
                    // Convert peers to int
                    var peersToRemove: [Int64] = []
                    for peerId in peerIds {
                        peersToRemove.append(peerId.toInt64())
                    }
                    print("Removing from \(groupId.rawValue) items: \(peersToRemove))")
                    Logger.shared.log("NiceFolders", "Removing from \(groupId.rawValue) items: \(peersToRemove))")
                    
                    // Generate final items list
                    let newFolderItems = Array(Set(folder.items).subtracting(peersToRemove))
                    
                    // Set new folder items
                    settings.folders[findex].items = newFolderItems
                    
                    // Stop
                    break
                }
            }
            // semaphore.signal()
            return settings
        }).start()
        */
    }
    
}


public func getPeerFolder(accountManager: AccountManager, peerId: PeerId) -> NiceFolder? {
    let niceFolders = getNiceFolders(accountManager: accountManager)
    
    for folder in niceFolders.folders {
        for item in folder.items {
            if item == peerId.toInt64() {
                return folder
            }
         }
    }
    
    return nil
}
