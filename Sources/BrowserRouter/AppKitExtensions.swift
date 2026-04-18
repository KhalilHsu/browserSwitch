import AppKit

extension NSPopUpButton {
    func selectItem(withRepresentedObject representedObject: String) {
        for item in itemArray where item.representedObject as? String == representedObject {
            select(item)
            return
        }
    }
}
