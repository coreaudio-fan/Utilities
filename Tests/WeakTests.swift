import Testing
@testable import Utilities

struct WeakTests {
	//	An empty class that can be instantiated and destroyed
	class TestClass {}

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
//		var initializeWithNil = Weak<TestClass>(nil)
	}
}
