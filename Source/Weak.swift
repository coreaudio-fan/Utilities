///	A weak reference that can be stored in a `Set` or used as a dictionary key.
///
///	Equality and hashing use an `ObjectIdentifier` captured in ``init(_:)``, so a wrapper keeps its
///	identity and stays findable after ``value`` becomes `nil`. `Sendable` when `T` is.
///
///	- Warning: Deallocated addresses are reused, so a wrapper around a new object can compare equal
///	to a stale one. Inserting it into a collection holding the stale wrapper does nothing.
public struct Weak<T: AnyObject>: Equatable, Hashable {
	///	The referenced object, or `nil` once it has been deallocated.
	public weak let value: T?

	///	The ObjectIdentifier of referenced object is used for testing equality and hashing so as to preserve as much
	///	of the functionality of the wrapper as possible even when the weak reference becomes nil.
	let id: ObjectIdentifier

	///	Creates a wrapper around the given object.
	///
	///	- Parameter value: The object to hold weakly.
	public init(_ value: T) {
		self.value = value
		self.id = ObjectIdentifier(value)
	}

	///	Hashes the captured identity, not the referent.
	///
	///	- Parameter hasher: The hasher to use.
	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	///	Compares the captured identities, not the current referents.
	///
	///	- Returns: `true` if both wrappers were created from the same object.
	public static func == (lhs: Weak<T>, rhs: Weak<T>) -> Bool {
		lhs.id == rhs.id
	}
}

//	Sendable when T is. Not a doc comment: DocC discards comments on conformance-only extensions.
extension Weak: Sendable where T: Sendable {}
