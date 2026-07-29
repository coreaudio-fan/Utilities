import Testing
@testable import Utilities

struct WeakTests {
	//	An empty class that can be instantiated and destroyed
	class TestClass {}

	//	A final class with no mutable state, so it satisfies Sendable and can exercise Weak's conditional conformance
	final class SendableTestClass: Sendable {}

	//	Accepts only a Sendable argument, so a successful call is a compile-time proof that the conformance holds
	private func requireSendable<T: Sendable>(_ candidate: T) -> T {
		candidate
	}

	@Test func normalUsage() async throws {
		//	Create a test object and put it in an optional so we can make it go away later
		var optionalObject: TestClass? = TestClass()

		//	Make a Weak that refers to the test object for later testing.
		let weakObject = Weak(optionalObject!)

		//	Create a Set whose elements hold weak references to TestClass.
		let weakObjects: Set<Weak<TestClass>> = [weakObject]

		//	Go through what is in the set and make sure it just has our one test object in it.
		#expect(weakObjects.count == 1)
		#expect(weakObjects.first?.value != nil)
		#expect(weakObjects.first == weakObject)
		#expect(weakObjects.first?.value === optionalObject!)

		//	make the test object go away by setting the optional to nil
		optionalObject = nil

		//	make sure what is in the set is correct
		#expect(weakObjects.count == 1)
		#expect(weakObjects.first?.value == nil)
		#expect(weakObjects.first == weakObject)
	}

	@Test func badUsage() async throws {
		//	Making a Weak requires a strong reference to an object which nil is not
//	var initializeWithNil = Weak<TestClass>(nil)
	}

	@Test func distinctObjectsStayDistinct() async throws {
		//	Two different objects have to produce wrappers that are unequal and can coexist in a Set
		let firstObject = TestClass()
		let secondObject = TestClass()

		#expect(Weak(firstObject) != Weak(secondObject))

		let weakObjects: Set<Weak<TestClass>> = [Weak(firstObject), Weak(secondObject)]
		#expect(weakObjects.count == 2)
	}

	@Test func sameObjectDeduplicates() async throws {
		//	Two wrappers around one object are equal, so a Set has to collapse them into a single element
		let object = TestClass()
		let firstWrapper = Weak(object)
		let secondWrapper = Weak(object)

		#expect(firstWrapper == secondWrapper)
		#expect(firstWrapper.hashValue == secondWrapper.hashValue)

		let weakObjects: Set<Weak<TestClass>> = [firstWrapper, secondWrapper]
		#expect(weakObjects.count == 1)
	}

	@Test func staleWrapperRemainsFindable() async throws {
		//	Identity is captured at init, so a wrapper stays locatable in a Set after its referent is gone.
		//	This is the mechanism behind the address reuse caveat documented on Weak.
		var optionalObject: TestClass? = TestClass()
		let weakObject = Weak(optionalObject!)
		let weakObjects: Set<Weak<TestClass>> = [weakObject]

		optionalObject = nil

		#expect(weakObjects.first?.value == nil)
		#expect(weakObjects.contains(weakObject))
	}

	@Test func sendableWhenReferentIsSendable() async throws {
		//	The call below only compiles because Weak<T> picks up Sendable when T has it
		let object = SendableTestClass()
		let weakObject = requireSendable(Weak(object))

		#expect(weakObject.value === object)
	}
}
