import AppKit

final class KeyboardController {
    private var downMonitor: Any?
    private var upMonitor: Any?

    var onSearch:     () -> Void = {}
    var onSpaceDown:  () -> Void = {}
    var onSpaceUp:    () -> Void = {}
    var onSeekLeft:   () -> Void = {}
    var onSeekRight:  () -> Void = {}
    var onVolumeUp:   () -> Void = {}
    var onVolumeDown: () -> Void = {}
    var onEscape:     () -> Void = {}

    func start() {
        guard downMonitor == nil else { return }

        downMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command, event.charactersIgnoringModifiers?.lowercased() == "f" {
                self.onSearch(); return nil
            }
            if Self.isTyping() { return event }
            switch event.keyCode {
            case 49:
                if !event.isARepeat { self.onSpaceDown() }
                return nil
            case 123: self.onSeekLeft();   return nil
            case 124: self.onSeekRight();  return nil
            case 126: self.onVolumeUp();   return nil
            case 125: self.onVolumeDown(); return nil
            case 53:  self.onEscape();     return nil
            default:  return event
            }
        }

        upMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 49 { self.onSpaceUp(); return nil }
            return event
        }
    }

    func stop() {
        if let downMonitor { NSEvent.removeMonitor(downMonitor) }
        if let upMonitor { NSEvent.removeMonitor(upMonitor) }
        downMonitor = nil
        upMonitor = nil
    }

    private static func isTyping() -> Bool {
        guard let r = NSApp.keyWindow?.firstResponder else { return false }
        return r is NSTextView || r is NSTextField
    }
}
