import Testing
@testable import Utilities

struct WeakTests {
	//	An empty class that can be instantiated and destroyed
	class TestClass {}

	@Test func normalUsage() async throws {
		//	create an object and put it in an optional
		var optionalObject1: TestClass? = TestClass()
		var optionalObject2: TestClass? = TestClass()

		//	create a Set to put the result in
		//	this actually tests the main reason Weak exists while we are at it
		var weakObjects: Set<Weak<TestClass>> = []
		
		//	lock down a strong reference
		if let object1 = optionalObject1, let object2 = optionalObject2 {
			//	the only safe way to make a weak reference is by using a strong reference
			weakObjects.insert(Weak(object1))
			weakObjects.insert(Weak(object2))

			//	make sure what we put in there, is in there
			#expect(weakObjects.count == 2)
			for weakObject in weakObjects {
				#expect(weakObject.value != nil)
				if weakObject.id == ObjectIdentifier(object1) {
					#expect(weakObject.value === object1)
					#expect(weakObject.value !== object2)
				}
				else if weakObject.id == ObjectIdentifier(object2) {
					#expect(weakObject.value !== object1)
					#expect(weakObject.value === object2)
				}
				else {
					Issue.record("Weak object doesn't match anything", severity: .error)
					return
				}
			}
		}
		else {
			Issue.record("No object to test against", severity: .error)
			return
		}
		
		//	set the first optional to nil to make it let go of the object
        optionalObject1 = nil
        optionalObject2 = nil

		//
		
		//	fetch the Weak and make sure it contains nil
//		let weakObject = set.first!
//		#expect(weakObject.value == nil)
    }
	
	@Test func badUsage() async throws {
		//	Making a Weak requires a strong reference to an object which nil is not
//		var initializeWithNil = Weak<TestClass>(nil)
	}
}
