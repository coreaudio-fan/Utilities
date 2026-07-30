import Foundation
import Testing
import Utilities

struct SerialNumberTests {
	//	Conforms only to SerialNumberFactory. Comparing two SerialNumber<OpaqueValue>s with ==
	//	is a compile error ("requires that 'OpaqueValue' conform to 'Equatable'"), so the gating of
	//	capabilities is enforced at compile time and has no runtime test.
	struct OpaqueValue: SerialNumberFactory {
		static func makeSerialNumber() -> OpaqueValue {
			OpaqueValue()
		}
	}

	@Test func serialUniqueness() async throws {
		let serials = (0..<1000).map { _ in SerialNumber<UInt64>() }

		#expect(Set(serials).count == serials.count)
	}

	@Test func concurrentUniqueness() async throws {
		let serials = await withTaskGroup(of: [SerialNumber<UInt64>].self) { group in
			for _ in 0..<8 {
				group.addTask {
					(0..<500).map { _ in SerialNumber<UInt64>() }
				}
			}

			return await group.reduce(into: [SerialNumber<UInt64>]()) { $0 += $1 }
		}

		#expect(serials.count == 4000)
		#expect(Set(serials).count == serials.count)
	}

	@Test func copyPropagation() async throws {
		let original = SerialNumber<UInt64>()
		let copy = original

		#expect(copy == original)
		#expect(copy.hashValue == original.hashValue)
		#expect(SerialNumber<UInt64>() != original)
	}

	@Test func creationOrder() async throws {
		let first = SerialNumber<UInt64>()
		let second = SerialNumber<UInt64>()

		#expect(first < second)

		let batch = (0..<100).map { _ in SerialNumber<UInt64>() }

		#expect(batch.sorted() == batch)
	}

	@Test func descriptionPassthrough() async throws {
		let serial = SerialNumber<UInt64>()

		#expect(serial.description == serial.value.description)
		#expect(String(describing: serial) == serial.value.description)
	}

	@Test func foundationUUIDGeneration() async throws {
		//	The stock UUID conformance draws random values
		let serials = (0..<100).map { _ in SerialNumber<UUID>() }

		#expect(Set(serials).count == serials.count)

		let original = try #require(serials.first)
		let copy = original

		#expect(copy == original)
	}

	@Test func minimalConformerConstructs() async throws {
		//	A value type with no capabilities beyond generation still constructs and reads
		let opaque = SerialNumber<OpaqueValue>()

		#expect(type(of: opaque.value) == OpaqueValue.self)
	}
}
