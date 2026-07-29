///	A wrapper for a weak reference that can be put in a container
public struct Weak<T: AnyObject>: Equatable, Hashable {
	///	The weak reference being stored
	public weak let value: T?

	///	The ObjectIdentifier of referenced object is used for testing equality and hashing so as to preserve as much
	///	of the functionality of the wrapper as possible even when the weak reference becomes nil.
	let id: ObjectIdentifier

	///	The main initializer, note that the strong reference to value is guaranteed to exist while the function runs
	///	making it the only time we can capture the ObjectIdentifier
	public init(_ value: T) {
		self.value = value
		self.id = ObjectIdentifier(value)
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	public static func == (lhs: Weak<T>, rhs: Weak<T>) -> Bool {
		lhs.id == rhs.id
	}
}

///	Weak<T> conforms to Sendable iff T does
extension Weak: Sendable where T: Sendable {}
