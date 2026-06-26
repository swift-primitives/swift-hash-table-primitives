// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Hash_Primitives
public import Index_Primitives

// MARK: - Hash.Table.Protocol (Hoisted as __HashTableProtocol)

/// Capability protocol unifying open-addressing position lookup across the
/// hash-table disciplines.
///
/// See ``Hash/Table/`Protocol``` for documentation.
///
/// ## What it unifies
///
/// Both the dynamic ``Hash/Table`` and the inline-capacity ``Hash/Table/Static``
/// expose the same open-addressing probe — *given a hash and an equality test,
/// return the external-storage position of the match, or `nil`*. They differ
/// only in the **position domain**: the dynamic table returns an unbounded
/// `Index<Element>`; the static table returns a capacity-bounded
/// `Index<Element>.Bounded<capacity>`. That single varying axis is captured by
/// the `Position` associated type, so membership logic (`contains`, the
/// position-probe terminal) is written once here and inherited by every
/// conforming table.
///
/// ## Capability, not op-dispatch
///
/// This is a *capability* surface in the sense of `Set.`Protocol`` /
/// `Buffer.`Protocol``: leaf membership operations stay **concrete witnesses on
/// the set** (per the 0-`witness_method` specialization evidence), and merely
/// *delegate their body* over this protocol via the `@inlinable`
/// position/`contains` terminals below — they are not re-expressed as
/// protocol-dispatched requirements. Because the conforming table is concrete
/// at every set call site, the delegation monomorphizes to direct calls.
///
/// ## Hoisted Protocol Pattern ([API-IMPL-009])
///
/// Swift does not allow nesting a protocol inside a generic type, so the
/// protocol is declared at module scope as `__HashTableProtocol` and aliased
/// into the namespace:
///
/// ```swift
/// extension Hash.Table {
///     public typealias `Protocol` = __HashTableProtocol
/// }
/// ```
public protocol __HashTableProtocol: ~Copyable {
    /// The external-storage position produced by a successful lookup.
    ///
    /// `Index<Element>` for the dynamic table; `Index<Element>.Bounded<capacity>`
    /// for the inline-capacity static table.
    associatedtype Position

    /// Finds the position for an element with the given hash value.
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to find.
    ///   - equals: A closure checking whether the element at a candidate position
    ///     matches the search element. Called on hash collisions.
    /// - Returns: The position in external storage if found, or `nil`.
    borrowing func position(
        forHash hashValue: Hash.Value,
        equals: (Position) -> Bool
    ) -> Position?

    /// Finds the position for an element with the given hash value, threading a
    /// borrowed context through `equals`.
    ///
    /// This overload avoids capturing the search element in the closure, which is
    /// required when the element is `borrowing` and `~Copyable`. The context is
    /// passed as a parameter to each `equals` invocation.
    ///
    /// - Parameters:
    ///   - hashValue: The hash value of the element to find.
    ///   - context: A value threaded through to `equals` on each probe.
    ///   - equals: A closure checking whether the element at a candidate position
    ///     matches `context`. Called on hash collisions.
    /// - Returns: The position in external storage if found, or `nil`.
    borrowing func position<Context: ~Copyable>(
        forHash hashValue: Hash.Value,
        context: borrowing Context,
        equals: (Position, borrowing Context) -> Bool
    ) -> Position?
}

// MARK: - Membership Terminal (delegation target for concrete witnesses)

extension __HashTableProtocol where Self: ~Copyable {
    /// Whether a matching element is present, threading a borrowed context.
    ///
    /// The single shared membership terminal: each set variant's concrete
    /// `contains` witness delegates its body here rather than re-deriving the
    /// `position(...) != nil` probe. `@inlinable` so the delegation
    /// monomorphizes to a direct call on the concrete conforming table.
    @inlinable
    public borrowing func contains<Context: ~Copyable>(
        forHash hashValue: Hash.Value,
        context: borrowing Context,
        equals: (Position, borrowing Context) -> Bool
    ) -> Bool {
        position(forHash: hashValue, context: context, equals: equals) != nil
    }
}

// MARK: - Namespace Typealias

extension Hash.Table where Element: ~Copyable {
    /// Capability protocol unifying open-addressing position lookup across the
    /// hash-table disciplines (`Hash.Table`, `Hash.Table.Static`).
    ///
    /// `Hash.Table.`Protocol`` declares the position-probe core — `position` keyed
    /// on a `Hash.Value` returning an associated `Position` — plus the derived
    /// `contains` membership terminal. Leaf set membership delegates its body over
    /// this protocol while remaining a concrete witness, preserving 0-`witness_method`
    /// specialization.
    ///
    /// `associatedtype Element: ~Copyable` on the owning `Hash.Table` relies on the
    /// `SuppressedAssociatedTypes` experimental feature.
    public typealias `Protocol` = __HashTableProtocol
}
