//	These tests exercise IdentifierFactory exactly as another module sees it, through a plain import.
//
//	Never add @testable to this file. It would make every internal declaration visible and silently destroy the one
//	thing this suite exists to check: that the published API is reachable from outside the framework.
//
//	Access control is enforced at compile time, so a regression breaks the build here rather than failing a test. The
//	#expect calls keep each test honest at runtime, but the fact that this file compiles at all is the real assertion.
import Testing
import Utilities

struct IdentifierFactoryAPITests {
	//	Accepts only an argument meeting the named constraint, so a successful call proves the conformance is visible
	//	from outside the framework rather than re-derived here.
	private func requireSendable<Candidate: Sendable>(_ candidate: Candidate) -> Candidate {
		candidate
	}

	@Test func clientCanConstruct() async throws {
		//	Reaches public init(). Were it the synthesized initializer, it would be internal and this would not build.
		let factory = IdentifierFactory<UInt64>()
		let identifier = factory.makeIdentifier()

		#expect(identifier != IdentifierFactory<UInt64>.sentinel)
	}

	@Test func clientCanReadSentinel() async throws {
		//	Reaches the public static sentinel as a plain UInt64
		let sentinel: UInt64 = IdentifierFactory<UInt64>.sentinel

		#expect(sentinel == 0)
	}

	@Test func clientCanUseSendable() async throws {
		let factory = requireSendable(IdentifierFactory<UInt64>())
		let identifier = factory.makeIdentifier()

		#expect(identifier == 1)
	}

	//	makeIdentifier() is 12 concrete overloads rather than one generic method, so each width is its own piece of
	//	published API and needs its own reachability check.
	@Test func clientCanGenerateAtSignedIntWidth() async throws {
		let factory = IdentifierFactory<Int>()
		let identifier: Int = factory.makeIdentifier()

		#expect(identifier == 1)
	}

	@Test func clientCanGenerateAtSigned8BitWidth() async throws {
		let factory = IdentifierFactory<Int8>()
		let identifier: Int8 = factory.makeIdentifier()

		#expect(identifier == 1)
	}

	@Test func clientCanGenerateAtSigned16BitWidth() async throws {
		let factory = IdentifierFactory<Int16>()
		let identifier: Int16 = factory.makeIdentifier()

		#expect(identifier == 1)
	}

	@Test func clientCanGenerateAtSigned32BitWidth() async throws {
		let factory = IdentifierFactory<Int32>()
		let identifier: Int32 = factory.makeIdentifier()

		#expect(identifier == 1)
	}

	@Test func clientCanGenerateAtSigned64BitWidth() async throws {
		let factory = IdentifierFactory<Int64>()
		let identifier: Int64 = factory.makeIdentifier()

		#expect(identifier == 1)
	}

	@Test func clientCanGenerateAtSigned128BitWidth() async throws {
		let factory = IdentifierFactory<Int128>()
		let identifier: Int128 = factory.makeIdentifier()

		#expect(identifier == 1)
	}

	@Test func clientCanGenerateAtUnsignedIntWidth() async throws {
		let factory = IdentifierFactory<UInt>()
		let identifier: UInt = factory.makeIdentifier()

		#expect(identifier == 1)
	}

	@Test func clientCanGenerateAt8BitWidth() async throws {
		let factory = IdentifierFactory<UInt8>()
		let identifier: UInt8 = factory.makeIdentifier()

		#expect(identifier == 1)
	}

	@Test func clientCanGenerateAt16BitWidth() async throws {
		let factory = IdentifierFactory<UInt16>()
		let identifier: UInt16 = factory.makeIdentifier()

		#expect(identifier == 1)
	}

	@Test func clientCanGenerateAt32BitWidth() async throws {
		let factory = IdentifierFactory<UInt32>()
		let identifier: UInt32 = factory.makeIdentifier()

		#expect(identifier == 1)
	}

	@Test func clientCanGenerateAt64BitWidth() async throws {
		let factory = IdentifierFactory<UInt64>()
		let identifier: UInt64 = factory.makeIdentifier()

		#expect(identifier == 1)
	}

	@Test func clientCanGenerateAt128BitWidth() async throws {
		let factory = IdentifierFactory<UInt128>()
		let identifier: UInt128 = factory.makeIdentifier()

		#expect(identifier == 1)
	}

	@Test func clientCanReadSentinelAtEveryWidth() async throws {
		//	sentinel is declared once generically, but reaching it at each width proves the constraint list on the type
		//	itself admits all six.
		#expect(IdentifierFactory<UInt>.sentinel == 0)
		#expect(IdentifierFactory<UInt8>.sentinel == 0)
		#expect(IdentifierFactory<UInt16>.sentinel == 0)
		#expect(IdentifierFactory<UInt32>.sentinel == 0)
		#expect(IdentifierFactory<UInt64>.sentinel == 0)
		#expect(IdentifierFactory<UInt128>.sentinel == 0)
	}
}
