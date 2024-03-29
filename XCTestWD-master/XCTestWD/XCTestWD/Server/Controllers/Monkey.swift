//
//  Monkey.swift
//  FastMonkey
//
//  fixed by zhangzhao on 2017/7/17.

import UIKit

/**
    A general-purpose class for implementing randomised
    UI tests. This class lets you schedule blocks to be
    run at random or fixed intervals, and provides helper
    functions to generate random coordinates.

    It has several extensions that implement actual event
    generation, using different methods. For normal usage,
    you will want to look at for instance the XCTest private
    API based extension.

    If all you want to do is geneate some events and you do
    not care about the finer details, you can just use a
    test case like the following:

    ```
    func testMonkey() {
        let application = XCUIApplication()

        // Workaround for bug in Xcode 7.3. Snapshots are not properly updated
        // when you initially call app.frame, resulting in a zero-sized rect.
        // Doing a random query seems to update everything properly.
        // TODO: Remove this when the Xcode bug is fixed!
        _ = application.descendants(matching: .any).element(boundBy: 0).frame

        // Initialise the monkey tester with the current device
        // frame. Giving an explicit seed will make it generate
        // the same sequence of events on each run, and leaving it
        // out will generate a new sequence on each run.
        let monkey = Monkey(frame: application.frame)
        //let monkey = Monkey(seed: 123, frame: application.frame)

        // Add actions for the monkey to perform. We just use a
        // default set of actions for this, which is usually enough.
        // Use either one of these but maybe not both.
        // XCTest private actions seem to work better at the moment.
        // UIAutomation actions seem to work only on the simulator.
        monkey.addDefaultXCTestPrivateActions()
        //monkey.addDefaultUIAutomationActions()

        // Occasionally, use the regular XCTest functionality
        // to check if an alert is shown, and click a random
        // button on it.
        monkey.addXCTestTapAlertAction(interval: 100, application: application)

        // Run the monkey test indefinitely.
        monkey.monkeyAround()
    }
    ```
*/
public class Monkey {
    let elapsedTime = 54000  // ?s
    let actionMax = 0
    let throttle = 0 * 1000  // ?ms *1000
    let randomize_throttle = false
    
    
    var r: Random
    let frame: CGRect

    var randomActions: [(accumulatedWeight: Double, action: () -> Void)]
    var totalWeight: Double

    var regularActions: [(interval: Int, action: () -> Void)]
    var actionCounter = 0
    
    var specalActions: [() -> Void]
    var actionSpecalCounter = 0
    let lock = DispatchSemaphore(value: 1)

    var checkActions: [(interval: Int, action: () -> Void)]
    var pid = 0
    
    var count = 0

    /**
        Create a Monkey object with a randomised seed.
        This instance will generate a different stream of
        events each time it is created.

        There is an XCTest bug to be aware of when finding
        the frame to use. Here is an example of how to work
        around this problem:

        ```
        let application = XCUIApplication()

        // Workaround for bug in Xcode 7.3 and later. Snapshots are not properly
        // updated when you initially call app.frame, resulting in a zero-sized rect.
        // Doing a random query seems to update everything properly.
        _ = application.descendants(matching: .any).element(boundBy: 0).frame

        let monkey = Monkey(frame: application.frame)
        ```

        - parameter frame: The frame to generate events in.
          Should be set to the size of the device being tested.
    */
    public convenience init(frame: CGRect) {
        let time = Date().timeIntervalSinceReferenceDate
        let seed = UInt32(UInt64(time * 1000) & 0xffffffff)
        self.init(seed: seed, frame: frame)
    }

    /**
        Create a Monkey object with a fixed seed.
        This instance will generate the exact same stream of
        events each time it is created.
        Create a Monkey object with a randomised seed.
        This instance will generate a different stream of
        events each time it is created.

        There is an XCTest bug to be aware of when finding
        the frame to use. Here is an example of how to work
        around this problem:

        ```
        let application = XCUIApplication()

        // Workaround for bug in Xcode 7.3 and later. Snapshots are not properly
        // updated when you initially call app.frame, resulting in a zero-sized rect.
        // Doing a random query seems to update everything properly.
        _ = application.descendants(matching: .any).element(boundBy: 0).frame

        let monkey = Monkey(seed: 0, frame: application.frame)
        ```

        - parameter seed: The random seed to use. Each value
          will generate a different stream of events.
        - parameter frame: The frame to generate events in.
          Should be set to the size of the device being tested.
    */
    public init(seed: UInt32, frame: CGRect) {
        self.r = Random(seed: seed)
        self.frame = frame
        self.randomActions = []
        self.totalWeight = 0
        self.regularActions = []
        self.specalActions = []
        self.checkActions = []
        self.pid = Int(XCTestWDFindElementUtils.getAppPid())
    }

    /**
        Generate a number of random events.

        - Parameter iterations: The number of random events
          to generate. Does not include any fixed interval
          events that may also be generated.
    */
    public func monkeyAround(iterations: Int) {
        DispatchQueue.global().async {
            while true{
                self.actCheck()
                usleep(500000)
            }
        }
        DispatchQueue.global().async {
            for _ in 1 ... iterations {
                self.actRandomly()
                self.actRegularly()
                self.actSpecial()
            }
        }
        DispatchQueue.global().async {
            if self.elapsedTime != 0{
                Thread.sleep(forTimeInterval: TimeInterval(self.elapsedTime))
                exit(0)
            }
            if self.actionMax != 0{
                while self.actionMax >= self.count{
                    usleep(500000)
                }
                exit(0)
            }
        }
    }

    /// Generate random events forever, or until the app crashes.
    public func monkeyAround() {
        DispatchQueue.global().async {
            while true{
                self.actCheck()
                usleep(500000)
            }
        }
        DispatchQueue.global().async {
            while true{
                self.actRandomly()
                self.actRegularly()
                self.actSpecial()
            }
        }
        DispatchQueue.global().async {
            if self.elapsedTime != 0{
                Thread.sleep(forTimeInterval: TimeInterval(self.elapsedTime))
                exit(0)
            }
            if self.actionMax != 0{
                while self.actionMax >= self.count{
                    usleep(500000)
                }
                exit(0)
            }
        }
    }

    public func actionLock(action:@escaping ()->Void){
        let work = DispatchWorkItem(qos:.default){
            self.lock.wait()
            self.count += 1
            action()
            if self.throttle != 0 {
                if self.randomize_throttle {
                    var throttle = self.r.randomInt(lessThan: self.throttle/1000)*1000
                    if throttle < 50*1000 {
                        throttle = 50*1000
                    }
                    usleep(useconds_t(throttle))
                }
                else{
                    usleep(useconds_t(self.throttle))
                }
            }
            self.lock.signal()
            return
        }
        DispatchQueue.main.sync(execute:work)
    }
    
    /// Generate one random event.
    public func actRandomly() {
        let x = r.randomDouble() * totalWeight
        for action in randomActions {
            if x < action.accumulatedWeight {
                actionLock(action: action.action)
                return
            }
        }
    }

    /// Generate any pending fixed-interval events.
    public func actRegularly() {
        actionCounter += 1
        for action in regularActions {
            if actionCounter % action.interval == 0 {
                actionLock(action: action.action)
            }
        }
    }

    /// Generate one special event, exp login event
    public func actSpecial(){
        actionSpecalCounter += 1
        if specalActions.count != 0 {
            let action = specalActions.removeFirst()
            actionLock(action: action)
            return
        }
    }
    
    /// Generate one check app event
    public func actCheck(){
        for action in checkActions {
            action.action()
        }
    }
    
    /**
        Add a block for generating randomised events.

        - parameter weight: The relative probability of this
          event being generated. Can be any value larger than
          zero. Probabilities will be normalised to the sum
          of all relative probabilities.
        - parameter action: The block to run when this event
          is generated.
    */
    public func addAction(weight: Double, action: @escaping () -> Void) {
        totalWeight += weight
        randomActions.append((accumulatedWeight: totalWeight, action: action))
    }

    /**
        Add a block for fixed-interval events.

        - parameter interval: How often to generate this
          event. One of these events will be generated after
          this many randomised events have been generated.
        - parameter action: The block to run when this event
          is generated.
    */
    public func addAction(interval: Int, action: @escaping () -> Void) {
        regularActions.append((interval: interval, action: action))
    }

    /**
        Add a block for generating check events
    */
    public func addCheck(interval:Int, action: @escaping () -> Void){
        checkActions.append((interval: interval, action: action))
    }

    /**
        Add a block for generating special events
    */
    public func addAction(action: @escaping () -> Void){
        specalActions.append(action)
    }

    /**
        Generate a random `Int`.

        - parameter lessThan: The returned value will be
          less than this value, and greater than or equal to zero.
    */
    public func randomInt(lessThan: Int) -> Int {
        return r.randomInt(lessThan: lessThan)
    }

    /**
        Generate a random `UInt`.

        - parameter lessThan: The returned value will be
          less than this value, and greater than or equal to  zero.
    */
    public func randomUInt(lessThan: UInt) -> UInt {
        return r.randomUInt(lessThan: lessThan)
    }

    /**
        Generate a random `CGFloat`.

        - parameter lessThan: The returned value will be
          less than this value, and greater than or equal to zero.
    */
    public func randomCGFloat(lessThan: CGFloat = 1) -> CGFloat {
        return CGFloat(r.randomDouble(lessThan: Double(lessThan)))
    }

    /// Generate a random `CGPoint` inside the frame of the app.
    public func randomPoint() -> CGPoint {
        return randomPoint(inRect: frame)
    }

    /**
        Generate a random `CGPoint` inside the frame of the app,
        avoiding the areas at the top and bottom of the screen
        that trigger a panel pull-out.
    */
    public func randomPointAvoidingPanelAreas() -> CGPoint {
        let topHeight: CGFloat = 20
        let bottomHeight: CGFloat = 20
        let frameWithoutTopAndBottom = CGRect(x: 0, y: topHeight, width: frame.width, height: frame.height - topHeight - bottomHeight)
        return randomPoint(inRect: frameWithoutTopAndBottom)
    }

    /**
        Generate a random `CGPoint` inside the given `CGRect`.

        - parameter inRect: The rect within which to pick the point.
    */
    public func randomPoint(inRect rect: CGRect) -> CGPoint {
        return CGPoint(x: rect.origin.x + randomCGFloat(lessThan: rect.size.width), y: rect.origin.y +  randomCGFloat(lessThan: rect.size.height))
    }

    public func randomSlipPoints() -> [CGPoint] {
        var points :[CGPoint] = []
        var x :CGFloat = 0
        if (arc4random() % 2 == 0){
            x = frame.size.width * 0.1
        } else {
            x = frame.size.width * 0.9
        }
        points.append(CGPoint(x: x , y: frame.size.height * 0.5))
        points.append(CGPoint(x: frame.size.width - x, y: frame.size.height * 0.5))
        return points
    }

    /// Generate a random `CGRect` inside the frame of the app.
    public func randomRect() -> CGRect {
        return rect(around: randomPoint(), inRect: frame)
    }

    /**
        Generate a random `CGRect` inside the frame of the app,
        sized to a given fraction of the whole frame.

        - parameter sizeFraction: The fraction of the size of
          the frame to use as the of the area for generated
          points.
    */
    public func randomRect(sizeFraction: CGFloat) -> CGRect {
        return rect(around: randomPoint(), sizeFraction: sizeFraction, inRect: frame)
    }

    /**    
        Generate an array of random `CGPoints` in a loose cluster.

        - parameter count: Number of points to generate.
    */
    public func randomClusteredPoints(count: Int) -> [CGPoint] {
        let centre = randomPoint()
        let clusterRect = rect(around: centre, inRect: frame)

        var points = [ centre ]
        for _ in 1..<count {
            points.append(randomPoint(inRect: clusterRect))
        }

        return points
    }

    func rect(around point: CGPoint, sizeFraction: CGFloat = 3, inRect: CGRect) -> CGRect {
        let size: CGFloat = min(frame.size.width, frame.size.height) / sizeFraction
        let x0: CGFloat = (point.x - frame.origin.x) * (frame.size.width - size) / frame.size.width + frame.origin.x
        let y0: CGFloat = (point.y - frame.origin.y) * (frame.size.height - size) / frame.size.width  + frame.origin.y
        return CGRect(x: x0, y: y0, width: size, height: size)
    }

    func sleep(_ seconds: Double) {
        if seconds>0 {
            usleep(UInt32(seconds * 1000000.0))
        }
    }
    
}

