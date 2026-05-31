import Foundation

// Conform to this protocol to add a new output driver (USB, sACN, Art-Net, etc.)
protocol DMXOutputDriver: AnyObject {
    var isEnabled: Bool { get set }
    func send(universe: Int, values: [UInt8])
    func start()
    func stop()
}

final class DMXOutputManager {
    private(set) var drivers: [any DMXOutputDriver] = []

    func addDriver(_ driver: some DMXOutputDriver) {
        drivers.append(driver)
    }

    func removeDriver(at index: Int) {
        guard index < drivers.count else { return }
        drivers[index].stop()
        drivers.remove(at: index)
    }

    func send(universe: Int, values: [UInt8]) {
        for driver in drivers where driver.isEnabled {
            driver.send(universe: universe, values: values)
        }
    }

    func startAll() { drivers.forEach { $0.start() } }
    func stopAll()  { drivers.forEach { $0.stop()  } }
}
