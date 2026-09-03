import Synchronization

///	Provides unique identifiers of type ID that are suitable to implement Identifiable<ID>.
///
///	Because of the way Atomic<Value> is defined, explicit concrete specializations for makeIdentifier() are required as
///	well. Note that this means that using an inappropriate type will be flagged by the compiler at the call site of
///	makeIdentifier() rather than at a variable declaration like other constraints. In all cases, the overflow checking
///	with the addition is intended to terminate the program when triggered since such an occurence cannot be recovered
///	from and most likely indicates the presence of a bug somewere.
///
///	Note that the ID values returned by an IdentifierFactory are only unique to the specfic instance that provided them.
///	This makes each instance essentially its own namespace for ID values regardless of type. Keeping this straight is
///	the responsibility of the user.
///
///	Implementations for sizes less than 32 bit sare provided for completeness. It is highly recommened to use a 32 bit
///	or larger type for ID to avoid running out of values prematurely which will terminate the program.
public final class IdentifierFactory<IDType: BinaryInteger & AtomicRepresentable & Sendable>: Sendable {

	///	Type type of the identifiers
	public typealias ID = IDType

	/// A value of ID that indicates the absence of a value, like nil is for reference types.
	@inlinable public static var sentinel: ID { 0 }

	///	Use an atomic counter that is only ever incremented to be thread safe cheaply. This also guarantees that
	///	makeIdentifier() returns a value that is not the sentinel, has never been returned before and wont ever be
	///	returned again.
	private let previousID = Atomic<ID>(0)

	///	The main initializer
	public init() {}

	///	The makeIdentifier implementation for Ints.
	public func makeIdentifier() -> ID where ID == Int {
		previousID.add(1, ordering: .relaxed).newValue
	}

	///	The makeIdentifier implementation for Int8s.
	public func makeIdentifier() -> ID where ID == Int8 {
		previousID.add(1, ordering: .relaxed).newValue
	}

	///	The makeIdentifier implementation for Int16s.
	public func makeIdentifier() -> ID where ID == Int16 {
		previousID.add(1, ordering: .relaxed).newValue
	}

	///	The makeIdentifier implementation for Int32s.
	public func makeIdentifier() -> ID where ID == Int32 {
		previousID.add(1, ordering: .relaxed).newValue
	}

	///	The makeIdentifier implementation for Int64s.
	public func makeIdentifier() -> ID where ID == Int64 {
		previousID.add(1, ordering: .relaxed).newValue
	}

	///	The makeIdentifier implementation for Int128s.
	public func makeIdentifier() -> ID where ID == Int128 {
		previousID.add(1, ordering: .relaxed).newValue
	}

	///	The makeIdentifier implementation for UInts.
	public func makeIdentifier() -> ID where ID == UInt {
		previousID.add(1, ordering: .relaxed).newValue
	}

	///	The makeIdentifier implementation for UInt8s.
	public func makeIdentifier() -> ID where ID == UInt8 {
		previousID.add(1, ordering: .relaxed).newValue
	}

	///	The makeIdentifier implementation for UInt16s.
	public func makeIdentifier() -> ID where ID == UInt16 {
		previousID.add(1, ordering: .relaxed).newValue
	}

	///	The makeIdentifier implementation for UInt32s.
	public func makeIdentifier() -> ID where ID == UInt32 {
		previousID.add(1, ordering: .relaxed).newValue
	}

	///	The makeIdentifier implementation for UInt64s.
	public func makeIdentifier() -> ID where ID == UInt64 {
		previousID.add(1, ordering: .relaxed).newValue
	}

	///	The makeIdentifier implementation for UInt128s.
	public func makeIdentifier() -> ID where ID == UInt128 {
		previousID.add(1, ordering: .relaxed).newValue
	}

}
