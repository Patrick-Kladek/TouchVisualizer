//
//  TouchVisualizer.swift
//  TouchVisualizer
//

import UIKit
import os.log

final public class Visualizer: NSObject {
    
    // MARK: - Public Variables
    static public let sharedInstance = Visualizer()
    private var enabled = false
    private var config: Configuration!
    private var touchViews = [TouchView]()
    private var previousLog = ""
    private var window: UIWindow!
    
    // MARK: - Object life cycle
    private override init() {
      super.init()
        NotificationCenter
            .default
            .addObserver(self, selector: #selector(Visualizer.orientationDidChangeNotification(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        UIDevice
            .current
            .beginGeneratingDeviceOrientationNotifications()
        
        warnIfSimulator()
    }
    
    deinit {
        NotificationCenter
            .default
            .removeObserver(self)
    }
    
    // MARK: - Helper Functions
    
    @objc internal func orientationDidChangeNotification(_ notification: Notification) {
        let instance = Visualizer.sharedInstance
        for touch in instance.touchViews {
            touch.removeFromSuperview()
        }
    }
    
    public func removeAllTouchViews() {
        for view in self.touchViews {
            view.removeFromSuperview()
        }
    }
}

extension Visualizer {
    public class func isEnabled() -> Bool {
        return sharedInstance.enabled
    }
    
    // MARK: - Start and Stop functions
    
    public class func start(_ config: Configuration = Configuration(), in window: UIWindow) {
		if config.showsLog {
            Logger.visualiser.info("Visualizer start...")
		}
        let instance = sharedInstance
        instance.window = window
        instance.enabled = true
        instance.config = config

        window.swizzle()

        for subview in window.subviews {
            if let subview = subview as? TouchView {
                subview.removeFromSuperview()
            }
        }
		if config.showsLog {
            Logger.visualiser.info("Started!")
		}
    }
    
    public class func stop() {
        let instance = sharedInstance
        instance.enabled = false
        
        for touch in instance.touchViews {
            touch.removeFromSuperview()
        }
    }
    
    public class func getTouches() -> [UITouch] {
        let instance = sharedInstance
        var touches: [UITouch] = []
        for view in instance.touchViews {
            guard let touch = view.touch else { continue }
            touches.append(touch)
        }
        return touches
    }
    
    // MARK: - Dequeue and locating TouchViews and handling events
    private func dequeueTouchView() -> TouchView {
        var touchView: TouchView?
        for view in touchViews {
            if view.superview == nil {
                touchView = view
                break
            }
        }
        
        if touchView == nil {
            touchView = TouchView()
            touchViews.append(touchView!)
        }
        
        return touchView!
    }
    
    private func findTouchView(_ touch: UITouch) -> TouchView? {
        for view in touchViews {
            if touch == view.touch {
                return view
            }
        }
        
        return nil
    }
    
    public func handleEvent(_ event: UIEvent) {
        if event.type != .touches {
            return
        }
        
        if !Visualizer.sharedInstance.enabled {
            return
        }

        var topWindow = self.window!
        for window in UIApplication.shared.windows {
            if window.isHidden == false && window.windowLevel > topWindow.windowLevel {
                topWindow = window
            }
        }
        
        for touch in event.allTouches! {
            let phase = touch.phase
            switch phase {
            case .began:
                let view = dequeueTouchView()
                view.config = Visualizer.sharedInstance.config
                view.touch = touch
                view.beginTouch()
                view.center = touch.location(in: topWindow)
                topWindow.addSubview(view)
            case .moved:
                if let view = findTouchView(touch) {
                    view.center = touch.location(in: topWindow)
                }
            case .ended, .cancelled:
                if let view = findTouchView(touch) {
                    UIView.animate(withDuration: 0.2, delay: 0.0, options: .allowUserInteraction, animations: { () -> Void  in
                        view.alpha = 0.0
                        view.endTouch()
                    }, completion: { [unowned self] (finished) -> Void in
                        view.removeFromSuperview()
                        self.log(touch)
                    })
                }
            case .stationary, .regionEntered, .regionMoved, .regionExited:
                break
            @unknown default:
                break
            }
            log(touch)
        }
    }
}

extension Visualizer {
    public func warnIfSimulator() {
        #if targetEnvironment(simulator)
            Logger.visualiser.warning("Warning: TouchRadius doesn't work on the simulator because it is not possible to read touch radius on it.")
        #endif
    }
    
    // MARK: - Logging
    public func log(_ touch: UITouch) {
        if !config.showsLog {
            return
        }
        
        var ti = 0
        var viewLogs = [[String:String]]()
        for view in touchViews {
            var index = ""
            
            index = "\(ti)"
            ti += 1
            
            var phase: String!
            switch touch.phase {
            case .began: phase = "B"
            case .moved: phase = "M"
            case .stationary: phase = "S"
            case .ended: phase = "E"
            case .cancelled: phase = "C"
            case .regionEntered: phase = "REN"
            case .regionMoved: phase = "RM"
            case .regionExited: phase = "REX"
            @unknown default: phase = "U"
            }
            
            let x = String(format: "%.02f", view.center.x)
            let y = String(format: "%.02f", view.center.y)
            let center = "(\(x), \(y))"
            let radius = String(format: "%.02f", touch.majorRadius)
            viewLogs.append(["index": index, "center": center, "phase": phase, "radius": radius])
        }
        
        var log = ""
        
        for viewLog in viewLogs {
            
            if (viewLog["index"]!).count == 0 {
                continue
            }
            
            let index = viewLog["index"]!
            let center = viewLog["center"]!
            let phase = viewLog["phase"]!
            let radius = viewLog["radius"]!
            log += "Touch: [\(index)]<\(phase)> c:\(center) r:\(radius)\t\n"
        }
        
        if log == previousLog {
            return
        }
        
        previousLog = log
        print(log, terminator: "")
    }
}

private extension Logger {

    private static var subsystem = Bundle(for: Visualizer.self).bundleIdentifier!

    /// Logs the view cycles like viewDidLoad.
    static let visualiser = Logger(subsystem: subsystem, category: "Visualiser")
}
