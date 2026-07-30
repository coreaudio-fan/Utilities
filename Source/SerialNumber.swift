#if canImport(Foundation)
import Foundation
#endif
import Synchronization

///	A value type that can issue fresh, never-repeating instances of itself.
///
///	A conformance guarantees that no two calls to ``makeSerialNumber()`` in a process return the
///	same value — by construction, like `UInt64`'s atomic counter, or statistically, like `UUID`'s
///	random draw — and owns whatever state its scheme takes.
public protocol SerialNumberValue {
	///	Returns a value that has never been returned before.
	static func makeSerialNumber() -> Self
}

///	A unique serial number, captured at initialization and propagated by copying.
///
///	Each ``init()`` takes a fresh value from `T`'s ``SerialNumberValue/makeSerialNumber()``, so no
///	two independently created serial numbers are alike; copies share their original's value. The
///	wrapper is `Equatable`, `Hashable`, `Comparable`, `Sendable`, and `CustomStringConvertible`
///	exactly when `T` is. For `UInt64`, comparison order is creation order.
public struct SerialNumber<T: SerialNumberValue> {
	///	The captured value.
	public let value: T

	///	Creates a serial number holding a value never issued before.
	public init() {
		self.value = T.makeSerialNumber()
	}
}

//	Capabilities follow T. Plain comments: DocC discards doc comments on conformance-only
//	extensions.
extension SerialNumber: Equatable where T: Equatable {}
extension SerialNumber: Hashable where T: Hashable {}
extension SerialNumber: Sendable where T: Sendable {}

extension SerialNumber: Comparable where T: Comparable {
	///	Orders serial numbers by their values.
	public static func < (lhs: SerialNumber<T>, rhs: SerialNumber<T>) -> Bool {
		lhs.value < rhs.value
	}
}

extension SerialNumber: CustomStringConvertible where T: CustomStringConvertible {
	///	The description of the captured value.
	public var description: String {
		value.description
	}
}

extension UInt64: SerialNumberValue {
	private static let serialNumberCounter = Atomic<UInt64>(0)

	///	Returns the next value of a strictly increasing counter, starting at 1.
	public static func makeSerialNumber() -> UInt64 {
		serialNumberCounter.wrappingAdd(1, ordering: .relaxed).newValue
	}
}

//	The DriverKit SDK has no Foundation, and driverkit is deliberately in SUPPORTED_PLATFORMS, so
//	the UUID conformance exists exactly where Foundation does.
#if canImport(Foundation)
extension UUID: SerialNumberValue {
	///	Returns a freshly drawn random (version 4) UUID.
	public static func makeSerialNumber() -> UUID {
		UUID()
	}
}
#endif
