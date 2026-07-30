///	A weak reference that can be stored in a `Set` or used as a dictionary key.
///
///	Equality and hashing use a ``SerialNumber`` minted in ``init(_:)``, so every wrapper is a
///	distinct entry with one stable identity: copies of a wrapper are equal, independently created
///	wrappers never are — even around the same object — and identity survives ``value`` becoming
///	`nil`. Insert a wrapper, keep a copy, and use it later to find or remove the entry.
///	`Sendable` when `T` is.
public struct Weak<T: AnyObject>: Equatable, Hashable {
	///	The referenced object, or `nil` once it has been deallocated.
	public weak let value: T?

	///	The wrapper's identity: minted at initialization, shared by copies, and never reused, so a
	///	stale wrapper cannot collide with a later one.
	let id: SerialNumber<UInt64>

	///	Creates a wrapper around the given object.
	///
	///	- Parameter value: The object to hold weakly.
	public init(_ value: T) {
		self.value = value
		self.id = SerialNumber<UInt64>()
	}

	///	Hashes the wrapper's identity, not the referent.
	///
	///	- Parameter hasher: The hasher to use.
	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	///	Compares the wrappers' identities, not their referents.
	///
	///	- Returns: `true` if both wrappers are copies of one original.
	public static func == (lhs: Weak<T>, rhs: Weak<T>) -> Bool {
		lhs.id == rhs.id
	}
}

//	Sendable when T is.
extension Weak: Sendable where T: Sendable {}
