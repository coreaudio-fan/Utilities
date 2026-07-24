///	A wrapper for a weak reference that can be put in a container.
///	Note how the ObjectIdentifier is captured in the initializer,
///	which is the only time a strong reference to the wrapped object is guaranteed to be available.
public struct Weak<T: AnyObject>: Equatable, Hashable {
	weak let value: T?
	let id: ObjectIdentifier
	
	init(_ value: T) {
		self.value = value
		id = ObjectIdentifier(value)
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
	
	public static func == (lhs: Weak<T>, rhs: Weak<T>) -> Bool {
		lhs.id == rhs.id
	}
}
