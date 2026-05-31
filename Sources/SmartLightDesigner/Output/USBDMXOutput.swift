import Foundation

// USB-DMX stub — drives ENTTEC Open DMX / Pro compatible interfaces.
// The serial port write format for ENTTEC Open DMX:
//   - Send a BREAK (set baud to 76800, write 0x00, restore baud 250000)
//   - Write DMX start code 0x00 followed by 512 channel bytes
//
// Full IOKit/serial implementation requires entitlements and hardware to test.
// This stub provides the interface so it can be wired up with ORSSerialPort
// or raw IOKit when running on actual hardware.

final class USBDMXOutput: DMXOutputDriver {
    var isEnabled: Bool
    var config: USBDMXConfiguration
    private var fileDescriptor: Int32 = -1
    var onSend: (([UInt8]) -> Void)?   // inject real serial write here

    init(config: USBDMXConfiguration) {
        self.config = config
        self.isEnabled = config.enabled
    }

    func start() {
        guard !config.portPath.isEmpty else { return }
        // Open serial port at 250000 baud when ORSSerialPort / IOKit is linked
        // fileDescriptor = open(config.portPath, O_RDWR | O_NOCTTY | O_NONBLOCK)
        // configureSerialPort(fileDescriptor)
    }

    func stop() {
        if fileDescriptor != -1 {
            // close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    func send(universe: Int, values: [UInt8]) {
        guard isEnabled, universe == config.universe else { return }
        let padded: [UInt8] = Array((values + Array(repeating: 0, count: 512)).prefix(512))
        onSend?(padded)
        // Real implementation would write DMX break + start code + padded to fileDescriptor
    }
}
