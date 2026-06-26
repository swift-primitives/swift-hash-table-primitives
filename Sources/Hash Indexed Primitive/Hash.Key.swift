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

extension Hash {
    /// THE single point of the hashed families' key bound (seat-ruled, 2026-06-10).
    ///
    /// On the 6.3.2 gate this is the institute's borrowing `Hash.`Protocol`` (which
    /// refines the equality protocol, so it carries `==` too). At the SE-0499 gate bump
    /// (`Hashable & ~Copyable`, Swift 6.4) the swap is THIS alias's target — every
    /// family bound (`Hash.Indexed`, `Set`, `Dictionary`) spells `Hash.Key` and moves
    /// mechanically.
    public typealias Key = Hash.`Protocol`
}
