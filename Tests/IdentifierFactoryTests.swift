import Testing
import Utilities

struct IdentifierFactoryTests {
	@Test func identifiersAreUnique() async throws {
		let factory = IdentifierFactory<UInt64>()
		let identifiers = (0 ..< 1000).map { _ in factory.makeIdentifier() }

		#expect(Set(identifiers).count == identifiers.count)
	}

	@Test func identifiersIncreaseMonotonically() async throws {
		let factory = IdentifierFactory<UInt64>()
		let identifiers = (0 ..< 100).map { _ in factory.makeIdentifier() }

		#expect(identifiers.sorted() == identifiers)
	}

	@Test func firstIdentifierIsNotTheSentinel() async throws {
		let factory = IdentifierFactory<UInt64>()

		#expect(factory.makeIdentifier() != IdentifierFactory<UInt64>.sentinel)
	}

	@Test func noIdentifierIsTheSentinel() async throws {
		let factory = IdentifierFactory<UInt64>()
		let identifiers = (0 ..< 1000).map { _ in factory.makeIdentifier() }

		#expect(identifiers.allSatisfy { $0 != IdentifierFactory<UInt64>.sentinel })
	}

	@Test func separateFactoriesCountIndependently() async throws {
		//	Each factory owns its counter, so two fresh factories hand out the same first identifier.
		let first = IdentifierFactory<UInt64>()
		let second = IdentifierFactory<UInt64>()

		#expect(first.makeIdentifier() == second.makeIdentifier())
	}

	@Test func referencesShareOneCounter() async throws {
		//	The counterpart to the test above: IdentifierFactory is a class, so a second reference to the same factory
		//	draws from the same counter rather than starting over. Together the two tests pin down the sharing
		//	semantics.
		let factory = IdentifierFactory<UInt64>()
		let alias = factory

		#expect(factory.makeIdentifier() == 1)
		#expect(alias.makeIdentifier() == 2)
		#expect(factory.makeIdentifier() == 3)
	}

	@Test func concurrentIdentifiersAreUnique() async throws {
		//	IdentifierFactory is a class, so one instance is shared across every task by reference with no wrapper
		//	needed.
		let factory = IdentifierFactory<UInt64>()
		let identifiers = await withTaskGroup(of: [UInt64].self) { group in
			for _ in 0 ..< 8 {
				group.addTask {
					(0 ..< 500).map { _ in factory.makeIdentifier() }
				}
			}

			return await group.reduce(into: [UInt64]()) { $0 += $1 }
		}

		#expect(identifiers.count == 4000)
		#expect(Set(identifiers).count == identifiers.count)
	}

	//	Each width needs its own test because makeIdentifier() is 12 concrete overloads rather than one generic
	//	method, so no single generic helper can drive them all.
	@Test func signedIntWidthGenerates() async throws {
		let factory = IdentifierFactory<Int>()

		#expect(factory.makeIdentifier() == 1)
		#expect(factory.makeIdentifier() == 2)
	}

	@Test func signed8BitWidthGenerates() async throws {
		let factory = IdentifierFactory<Int8>()

		#expect(factory.makeIdentifier() == 1)
		#expect(factory.makeIdentifier() == 2)
	}

	@Test func signed16BitWidthGenerates() async throws {
		let factory = IdentifierFactory<Int16>()

		#expect(factory.makeIdentifier() == 1)
		#expect(factory.makeIdentifier() == 2)
	}

	@Test func signed32BitWidthGenerates() async throws {
		let factory = IdentifierFactory<Int32>()

		#expect(factory.makeIdentifier() == 1)
		#expect(factory.makeIdentifier() == 2)
	}

	@Test func signed64BitWidthGenerates() async throws {
		let factory = IdentifierFactory<Int64>()

		#expect(factory.makeIdentifier() == 1)
		#expect(factory.makeIdentifier() == 2)
	}

	@Test func signed128BitWidthGenerates() async throws {
		let factory = IdentifierFactory<Int128>()

		#expect(factory.makeIdentifier() == 1)
		#expect(factory.makeIdentifier() == 2)
	}

	@Test func unsignedIntWidthGenerates() async throws {
		let factory = IdentifierFactory<UInt>()

		#expect(factory.makeIdentifier() == 1)
		#expect(factory.makeIdentifier() == 2)
	}

	@Test func unsigned8BitWidthGenerates() async throws {
		let factory = IdentifierFactory<UInt8>()

		#expect(factory.makeIdentifier() == 1)
		#expect(factory.makeIdentifier() == 2)
	}

	@Test func unsigned16BitWidthGenerates() async throws {
		let factory = IdentifierFactory<UInt16>()

		#expect(factory.makeIdentifier() == 1)
		#expect(factory.makeIdentifier() == 2)
	}

	@Test func unsigned32BitWidthGenerates() async throws {
		let factory = IdentifierFactory<UInt32>()

		#expect(factory.makeIdentifier() == 1)
		#expect(factory.makeIdentifier() == 2)
	}

	@Test func unsigned64BitWidthGenerates() async throws {
		let factory = IdentifierFactory<UInt64>()

		#expect(factory.makeIdentifier() == 1)
		#expect(factory.makeIdentifier() == 2)
	}

	@Test func unsigned128BitWidthGenerates() async throws {
		let factory = IdentifierFactory<UInt128>()

		#expect(factory.makeIdentifier() == 1)
		#expect(factory.makeIdentifier() == 2)
	}

	@Test func sentinelIsZeroAtEveryWidth() async throws {
		#expect(IdentifierFactory<Int>.sentinel == 0)
		#expect(IdentifierFactory<Int8>.sentinel == 0)
		#expect(IdentifierFactory<Int16>.sentinel == 0)
		#expect(IdentifierFactory<Int32>.sentinel == 0)
		#expect(IdentifierFactory<Int64>.sentinel == 0)
		#expect(IdentifierFactory<Int128>.sentinel == 0)
		#expect(IdentifierFactory<UInt>.sentinel == 0)
		#expect(IdentifierFactory<UInt8>.sentinel == 0)
		#expect(IdentifierFactory<UInt16>.sentinel == 0)
		#expect(IdentifierFactory<UInt32>.sentinel == 0)
		#expect(IdentifierFactory<UInt64>.sentinel == 0)
		#expect(IdentifierFactory<UInt128>.sentinel == 0)
	}

	@Test func narrowWidthSignedYieldsItsFullRange() async throws {
		//	The counter starts at 0 and makeIdentifier() returns the post-increment value, so a UInt8 factory yields
		//	the whole 1 ... 127 range. The next call would compute 256 and trap, deliberately terminating the program
		//	rather than wrapping and reissuing identifiers. That call is not exercised here — a trap cannot be caught
		//	by the test runner.
		let factory = IdentifierFactory<Int8>()
		let identifiers = (0 ..< 127).map { _ in factory.makeIdentifier() }

		#expect(identifiers.first == 1)
		#expect(identifiers.last == Int8.max)
		#expect(Set(identifiers).count == identifiers.count)
	}

	@Test func narrowWidthUnsignedYieldsItsFullRange() async throws {
		//	The counter starts at 0 and makeIdentifier() returns the post-increment value, so a UInt8 factory yields
		//	the whole 1 ... 255 range. The next call would compute 256 and trap, deliberately terminating the program
		//	rather than wrapping and reissuing identifiers. That call is not exercised here — a trap cannot be caught
		//	by the test runner.
		let factory = IdentifierFactory<UInt8>()
		let identifiers = (0 ..< 255).map { _ in factory.makeIdentifier() }

		#expect(identifiers.first == 1)
		#expect(identifiers.last == UInt8.max)
		#expect(Set(identifiers).count == identifiers.count)
	}
}
