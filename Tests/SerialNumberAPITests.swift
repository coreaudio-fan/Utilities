//	These tests exercise SerialNumber and SerialNumberFactory exactly as another module sees
//	them, through a plain import.
//
//	Never add @testable to this file. It would make every internal declaration visible and silently
//	destroy the one thing this suite exists to check: that the published API is reachable from
//	outside the framework.
//
//	Access control is enforced at compile time, so a regression breaks the build here rather than
//	failing a test. The #expect calls keep each test honest at runtime, but the fact that this file
//	compiles at all is the real assertion.
import Foundation
import Testing
import Utilities

struct SerialNumberAPITests {
	//	A client-side conformance, proving the protocol and its requirement are published
	struct ClientValue: SerialNumberFactory, Equatable {
		let raw: UInt64

		static func makeSerialNumber() -> ClientValue {
			ClientValue(raw: UInt64.makeSerialNumber())
		}
	}

	//	Each of these accepts only an argument meeting the named constraint, so a successful call
	//	proves the conformance is visible from outside the framework rather than re-derived here.
	private func requireEquatable<T: Equatable>(_ candidate: T) -> T {
		candidate
	}

	private func requireHashable<T: Hashable>(_ candidate: T) -> T {
		candidate
	}

	private func requireComparable<T: Comparable>(_ candidate: T) -> T {
		candidate
	}

	private func requireSendable<T: Sendable>(_ candidate: T) -> T {
		candidate
	}

	@Test func clientCanConstruct() async throws {
		//	Reaches public init(); distinct values are the documented generation contract
		let first = SerialNumber<UInt64>()
		let second = SerialNumber<UInt64>()

		#expect(first.value != second.value)
	}

	@Test func clientCanReadValue() async throws {
		//	Reaches the public value property as a plain UInt64
		let serial = SerialNumber<UInt64>()
		let extracted: UInt64 = serial.value

		#expect(extracted == serial.value)
	}

	@Test func clientCanConformOwnType() async throws {
		//	Compiles only while SerialNumberFactory and its requirement are public
		let serial = SerialNumber<ClientValue>()

		#expect(serial.value.raw != 0)
	}

	@Test func clientCanGenerateDirectly() async throws {
		//	UInt64.makeSerialNumber() is reachable API in its own right
		let first = UInt64.makeSerialNumber()
		let second = UInt64.makeSerialNumber()

		#expect(first != second)
	}

	@Test func clientCanUseEquatable() async throws {
		let serial = requireEquatable(SerialNumber<UInt64>())

		#expect(serial == serial)
		#expect(serial != SerialNumber<UInt64>())
	}

	@Test func clientCanUseHashable() async throws {
		let serial = requireHashable(SerialNumber<UInt64>())
		let copy = serial

		#expect(serial.hashValue == copy.hashValue)

		let serials: Set<SerialNumber<UInt64>> = [serial, copy, SerialNumber<UInt64>()]

		#expect(serials.count == 2)

		let labels: [SerialNumber<UInt64>: String] = [serial: "first"]

		#expect(labels[copy] == "first")
	}

	@Test func clientCanUseComparable() async throws {
		let earlier = requireComparable(SerialNumber<UInt64>())
		let later = SerialNumber<UInt64>()

		#expect(earlier < later)
	}

	@Test func clientCanUseSendableConditionally() async throws {
		//	Compiles only while the conditional Sendable conformance is part of the API
		let serial = requireSendable(SerialNumber<UInt64>())

		#expect(serial == serial)
	}

	@Test func clientCanUseFoundationUUID() async throws {
		//	The UUID conformance is published; UUID brings Equatable, Hashable, Comparable,
		//	Sendable, and CustomStringConvertible with it
		let serial = requireSendable(requireComparable(requireHashable(SerialNumber<UUID>())))

		#expect(serial != SerialNumber<UUID>())
		#expect(!serial.description.isEmpty)
	}

	@Test func clientCanUseDescription() async throws {
		let serial = SerialNumber<UInt64>()

		#expect(!serial.description.isEmpty)
	}
}
