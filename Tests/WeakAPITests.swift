//	These tests exercise Utilities exactly as another module sees it, through a plain import.
//
//	Never add @testable to this file. It would make every internal declaration visible and silently
//	destroy the one thing this suite exists to check: that the published API is reachable from
//	outside the framework. Weak was once public with an internal initializer, and the functional
//	tests passed anyway, because @testable bypasses access control entirely.
//
//	Access control is enforced at compile time, so a regression breaks the build here rather than
//	failing a test. The #expect calls keep each test honest at runtime, but the fact that this file
//	compiles at all is the real assertion.
import Testing
import Utilities

struct WeakAPITests {
	//	A plain reference type standing in for whatever a client chooses to wrap
	final class Referent {}

	//	A Sendable reference type, to check that Weak's conditional Sendable conformance is published
	final class SendableReferent: Sendable {}

	//	Each of these accepts only an argument meeting the named constraint, so a successful call
	//	proves the conformance is visible from outside the framework rather than re-derived here.
	private func requireEquatable<T: Equatable>(_ candidate: T) -> T {
		candidate
	}

	private func requireHashable<T: Hashable>(_ candidate: T) -> T {
		candidate
	}

	private func requireSendable<T: Sendable>(_ candidate: T) -> T {
		candidate
	}

	@Test func clientCanConstruct() async throws {
		//	Reaches public init(_:), the member that was unreachable when this gap was found
		let referent = Referent()
		let wrapper = Weak(referent)

		#expect(wrapper.value === referent)
	}

	@Test func clientCanReadReferent() async throws {
		//	Reaches the public value property, both while the referent lives and once it is gone
		var referent: Referent? = Referent()
		let wrapper = Weak(try #require(referent))

		#expect(wrapper.value != nil)

		referent = nil

		#expect(wrapper.value == nil)
	}

	@Test func clientCanUseEquatable() async throws {
		//	Reaches the public == operator; only copies of a wrapper are equal
		let referent = Referent()
		let wrapper = requireEquatable(Weak(referent))
		let copy = wrapper

		#expect(wrapper == copy)
		#expect(wrapper != Weak(referent))
	}

	@Test func clientCanUseHashable() async throws {
		let referent = Referent()
		let wrapper = requireHashable(Weak(referent))
		let copy = wrapper

		//	Equal wrappers must agree on hashValue, which is the contract a client depends on
		#expect(wrapper.hashValue == copy.hashValue)

		//	Reaches hash(into:) directly rather than through the synthesized hashValue
		var firstHasher = Hasher()
		var secondHasher = Hasher()
		wrapper.hash(into: &firstHasher)
		copy.hash(into: &secondHasher)

		#expect(firstHasher.finalize() == secondHasher.finalize())
	}

	@Test func clientCanUseSendableConditionally() async throws {
		//	Compiles only while "extension Weak: Sendable where T: Sendable" is part of the API
		let referent = SendableReferent()
		let wrapper = requireSendable(Weak(referent))

		#expect(wrapper.value === referent)
	}

	@Test func clientCanStoreInSetAndDictionary() async throws {
		//	The containers Weak exists to serve; lookup goes through a kept copy of the wrapper
		let firstEntry = Weak(Referent())
		let secondEntry = Weak(Referent())

		let wrappers: Set<Weak<Referent>> = [firstEntry, secondEntry, firstEntry]

		#expect(wrappers.count == 2)
		#expect(wrappers.contains(firstEntry))

		let labels: [Weak<Referent>: String] = [firstEntry: "first", secondEntry: "second"]

		#expect(labels[firstEntry] == "first")
	}
}
