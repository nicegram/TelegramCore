import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public enum TogglePeerChatPinnedResult {
    case done
    case limitExceeded(Int)
}

public func toggleItemPinned(postbox: Postbox, groupId: PeerGroupId, itemId: PinnedItemId) -> Signal<TogglePeerChatPinnedResult, NoError> {
    return postbox.transaction { transaction -> TogglePeerChatPinnedResult in
        var itemIds = transaction.getPinnedItemIds(groupId: groupId)
        let sameKind = itemIds.filter { item in
            switch itemId {
                case let .peer(lhsPeerId):
                    if case let .peer(rhsPeerId) = item {
                        return (lhsPeerId.namespace == Namespaces.Peer.SecretChat) == (rhsPeerId.namespace == Namespaces.Peer.SecretChat) && lhsPeerId != rhsPeerId
                    } else {
                        return false
                    }
            }
            
        }
        
        let additionalCount: Int
        if let _ = itemIds.index(of: itemId) {
            additionalCount = -1
        } else {
            additionalCount = 1
        }
        
        let limitsConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration ?? LimitsConfiguration.defaultValue
        let limitCount: Int
        if case .root = groupId {
            limitCount = Int(limitsConfiguration.maxPinnedChatCount)
        } else {
            limitCount = Int(limitsConfiguration.maxArchivedPinnedChatCount)
        }
        
        if let index = itemIds.index(of: itemId) {
            itemIds.remove(at: index)
        } else {
            itemIds.insert(itemId, at: 0)
        }
        if !(sameKind.count + additionalCount > limitCount) {
            addSynchronizePinnedChatsOperation(transaction: transaction, groupId: groupId)
        }
        transaction.setPinnedItemIds(groupId: groupId, itemIds: itemIds)
        return .done
    }
}

public func reorderPinnedItemIds(transaction: Transaction, groupId: PeerGroupId, itemIds: [PinnedItemId]) -> Bool {
    if transaction.getPinnedItemIds(groupId: groupId) != itemIds {
        transaction.setPinnedItemIds(groupId: groupId, itemIds: itemIds)
        let limitsConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration ?? LimitsConfiguration.defaultValue
        let limitCount: Int?
        if case .root = groupId {
            limitCount = Int(limitsConfiguration.maxPinnedChatCount)
        } else {
            limitCount = nil
        }
        if limitCount != nil && itemIds.count <= limitCount! {
            addSynchronizePinnedChatsOperation(transaction: transaction, groupId: groupId)
        }
        return true
    } else {
        return false
    }
}
