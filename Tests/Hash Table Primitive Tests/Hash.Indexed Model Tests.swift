import Buffer_Linear_Primitive
import Buffer_Primitive
public import Buffer_Primitives_Test_Support
public import Hash_Primitives
import Hash_Table_Primitives
import Hash_Table_Primitives_Test_Support
import Index_Primitives
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Storage_Contiguous_Primitives
import Storage_Primitive
import Tagged_Primitives_Standard_Library_Integration
import Testing

// The W1 proving suite (arc-2, model-based randomized testing): SEEDED op streams
// drive the ordered hashed column AND the bare engine against trivially-correct
// reference models, with full-state equivalence + the Hash.Coherence laws between
// ops. A divergence fails with seed + full op transcript — the replayable repro.
//
// Determinism: the op STREAM is fully deterministic per seed (generation reads
// model state only, never SUT state). Bucket LAYOUT is not replayable by design:
// stdlib `Hasher` is per-process seeded and the engine's per-instance `_seed` is
// random (`SWIFT_DETERMINISTIC_HASHING=1` pins the former; nothing pins the
// latter). Logic divergences replay exactly; layout-shape findings replay
// statistically across the seed set.
//
// Shape constraint: each op is its OWN small method on a ~Copyable stream struct.
// A single large stream body (loop + 10-case switch + move-only traffic) sends
// 6.3.2's -Onone `MovedAsyncVarDebugInfoPropagator` SIL pass into a >1h spin
// (evidence: /tmp/arc2-w1-silhang/). Keep stream bodies small.

private typealias HeapStorage<E: ~Copyable> =
    Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>

private typealias DenseColumn<E: ~Copyable> = Buffer<HeapStorage<E>>.Linear
private typealias OrderedColumn<E: Hash.Key & ~Copyable> = Hash.Indexed<DenseColumn<E>>

/// Routes through the PROTOCOL's typed accessor (the stdlib `Int.hashValue`
/// shadows it in concrete contexts).
private func typedHash<T: Hash.`Protocol` & ~Copyable>(_ value: borrowing T) -> Hash.Value {
    value.hashValue
}

// MARK: - The member fixture: equality binds to `id`, hashing binds to `group`
// (hash coarser than equality = lawful collisions on demand)

private struct Key: Hash.`Protocol` {
    let id: Int
    let group: Int

    init(id: Int, group: Int) {
        self.id = id
        self.group = group
    }

    init(id: Int, collisionDivisor: Int) {
        self.init(id: id, group: id / collisionDivisor)
    }

    borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(group)
    }

    static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - The reference model: an insertion-ordered member list (stdlib value
// semantics; position = array index; removal = order-preserving remove(at:))

private struct Reference {
    var members: [Key] = []
    var ids: Swift.Set<Int> = []
    /// Retired (id, group) pairs: miss-probes aimed into the exact chains the
    /// ids used to occupy (a stale entry would resurface here).
    var graveyard: [(id: Int, group: Int)] = []

    mutating func append(_ key: Key) {
        members.append(key)
        ids.insert(key.id)
    }

    mutating func remove(at index: Int) {
        let key = members.remove(at: index)
        ids.remove(key.id)
        retire(key)
    }

    mutating func replace(at index: Int, with key: Key) {
        let old = members[index]
        ids.remove(old.id)
        retire(old)
        members[index] = key
        ids.insert(key.id)
    }

    mutating func removeAll() {
        for key in members.prefix(4) { retire(key) }
        members.removeAll()
        ids.removeAll()
    }

    private mutating func retire(_ key: Key) {
        graveyard.append((key.id, key.group))
        if graveyard.count > 8 {
            graveyard.removeFirst(graveyard.count - 8)
        }
    }
}

/// Full-state equivalence + the engine's own laws: count, per-slot insertion
/// order, findability at the model position, graveyard misses, Hash.Coherence 1–3.
private func audit(_ column: borrowing OrderedColumn<Key>, against model: Reference) -> [String] {
    var findings: [String] = []

    let count = column.count
    if count != Index<Key>.Count(UInt(model.members.count)) {
        findings.append("count: column \(count), model \(model.members.count)")
    }

    for (offset, member) in model.members.enumerated() {
        let slot = Index<Key>(Ordinal(UInt(offset)))
        let resident = column[slot]
        if resident.id != member.id {
            findings.append("slot \(offset): column holds id \(resident.id), model id \(member.id)")
        }
        let position = column.position(of: member)
        if position != slot {
            findings.append("position(of: id \(member.id)): \(String(describing: position)), model slot \(offset)")
        }
    }

    for retired in model.graveyard where !model.ids.contains(retired.id) {
        if column.contains(Key(id: retired.id, group: retired.group)) {
            findings.append("retired id \(retired.id) (group \(retired.group)) is still reachable")
        }
    }

    findings.append(contentsOf: Hash.Coherence.violations(column))
    return findings
}

// MARK: - The ordered-column op stream

private struct OrderedStream: ~Copyable {
    var column: OrderedColumn<Key>
    var model = Reference()
    var rng: Model.Random
    var verdict: Model.Verdict
    var nextID = 0
    let collisionDivisor: Int

    init(seed: UInt64, collisionDivisor: Int) {
        var rng = Model.Random(seed: seed)
        self.column = OrderedColumn<Key>(minimumCapacity: Index<Key>.Count(UInt(rng.below(17))))
        self.rng = rng
        self.verdict = Model.Verdict(seed: seed)
        self.collisionDivisor = collisionDivisor
    }

    mutating func freshKey() -> Key {
        let key = Key(id: nextID, collisionDivisor: collisionDivisor)
        nextID += 1
        return key
    }

    mutating func insertFresh() {
        let key = freshKey()
        verdict.record("insert id=\(key.id) g=\(key.group)")
        if let rejected = column.insert(key) {
            verdict.diverged(["insert of fresh id \(rejected.id) was rejected as a duplicate"])
        } else {
            model.append(key)
        }
    }

    mutating func insertDuplicate() {
        let pick = model.members[rng.below(model.members.count)]
        verdict.record("dup id=\(pick.id)")
        if let rejected = column.insert(Key(id: pick.id, group: pick.group)) {
            if rejected.id != pick.id {
                verdict.diverged(["duplicate hand-back id \(rejected.id), expected \(pick.id)"])
            }
        } else {
            verdict.diverged(["duplicate id \(pick.id) was inserted as fresh"])
        }
    }

    mutating func removePresent() {
        let index = rng.below(model.members.count)
        let pick = model.members[index]
        verdict.record("remove id=\(pick.id) @\(index)")
        if let removed = column.remove(pick) {
            if removed.id != pick.id {
                verdict.diverged(["remove(id \(pick.id)) returned id \(removed.id)"])
            }
            model.remove(at: index)
        } else {
            verdict.diverged(["remove(id \(pick.id)) found nothing for a live member"])
        }
    }

    mutating func removeAbsent() {
        let key = freshKey()
        verdict.record("absent id=\(key.id)")
        if let removed = column.remove(key) {
            verdict.diverged(["remove of never-inserted id \(key.id) returned id \(removed.id)"])
        }
    }

    mutating func containsHit() {
        let pick = model.members[rng.below(model.members.count)]
        verdict.record("has id=\(pick.id)")
        if !column.contains(pick) {
            verdict.diverged(["live id \(pick.id) is not contained"])
        }
    }

    mutating func containsMiss() {
        let key = freshKey()
        verdict.record("miss id=\(key.id)")
        if column.contains(key) {
            verdict.diverged(["never-inserted id \(key.id) is contained"])
        }
    }

    mutating func positionHit() {
        let index = rng.below(model.members.count)
        let pick = model.members[index]
        verdict.record("pos id=\(pick.id) @\(index)")
        let position = column.position(of: pick)
        if position != Index<Key>(Ordinal(UInt(index))) {
            verdict.diverged(["position(of: id \(pick.id)): \(String(describing: position)), model \(index)"])
        }
    }

    mutating func mutateRehash() {
        let index = rng.below(model.members.count)
        let old = model.members[index]
        let new = freshKey()
        verdict.record("mutate@\(index) \(old.id)→\(new.id) g\(old.group)→g\(new.group)")
        column[Index<Key>(Ordinal(UInt(index)))] = new
        model.replace(at: index, with: new)
    }

    mutating func mutateSameGroup() {
        let index = rng.below(model.members.count)
        let old = model.members[index]
        let new = Key(id: nextID, group: old.group)
        nextID += 1
        verdict.record("mutate=@\(index) \(old.id)→\(new.id) g\(old.group)")
        column[Index<Key>(Ordinal(UInt(index)))] = new
        model.replace(at: index, with: new)
    }

    mutating func growthBurst() {
        let first = nextID
        for _ in 0..<12 {
            let key = freshKey()
            if let rejected = column.insert(key) {
                verdict.diverged(["burst insert of fresh id \(rejected.id) was rejected"])
                return
            }
            model.append(key)
        }
        verdict.record("burst ×12 ids \(first)..\(nextID - 1)")
    }

    mutating func cloneCheck() {
        verdict.record("clone")
        var copy = column.clone()
        if copy.count != Index<Key>.Count(UInt(model.members.count)) {
            verdict.diverged(["clone count \(copy.count), model \(model.members.count)"])
        }
        if !model.members.isEmpty {
            let pick = model.members[rng.below(model.members.count)]
            if !copy.contains(pick) {
                verdict.diverged(["clone lost live id \(pick.id)"])
            }
        }
        let marker = Key(id: -(verdict.transcript.count), group: 0)
        copy.insert(marker)
        if column.contains(marker) {
            verdict.diverged(["clone shares state: marker id \(marker.id) leaked to the original"])
        }
    }

    mutating func wipe() {
        let keep = rng.chance(50)
        verdict.record("wipe keep=\(keep)")
        column.removeAll(keepingCapacity: keep)
        model.removeAll()
    }

    mutating func step() {
        var branch = rng.below(100)
        if model.members.isEmpty, branch >= 26 { branch = 0 }
        switch branch {
        case 0..<26: insertFresh()
        case 26..<34: insertDuplicate()
        case 34..<56: removePresent()
        case 56..<60: removeAbsent()
        case 60..<71: containsHit()
        case 71..<75: containsMiss()
        case 75..<81: positionHit()
        case 81..<89: mutateRehash()
        case 89..<93: mutateSameGroup()
        case 93..<96: growthBurst()
        case 96..<98: cloneCheck()
        default: wipe()
        }
    }

    mutating func run() {
        let operations = Model.operations(default: 1_000)
        var op = 0
        while op < operations, verdict.isClean {
            step()
            if Model.shouldAudit(op: op, of: operations) {
                verdict.diverged(audit(column, against: model))
            }
            op += 1
        }
    }

    consuming func finish() -> Model.Verdict {
        verdict
    }
}

private func runOrderedStream(seed: UInt64, collisionDivisor: Int) -> Model.Verdict {
    var stream = OrderedStream(seed: seed, collisionDivisor: collisionDivisor)
    stream.run()
    return stream.finish()
}

// MARK: - The bare-engine op stream (the checked-insert door + chain repair,
// positions = append-only mint order over hypothetical external storage)

private struct EngineStream: ~Copyable {
    var table: Hash.Table<Key>
    var liveIDs: [Int] = []
    var byID: [Int: (group: Int, position: Int)] = [:]
    var graveyard: [(id: Int, group: Int)] = []
    var rng: Model.Random
    var verdict: Model.Verdict
    var nextID = 0
    var nextPosition = 0
    let collisionDivisor = 4

    init(seed: UInt64) {
        var rng = Model.Random(seed: seed)
        self.table = Hash.Table<Key>(minimumCapacity: Index<Key>.Count(UInt(rng.below(17))))
        self.rng = rng
        self.verdict = Model.Verdict(seed: seed)
    }

    func positionIndex(_ position: Int) -> Index<Key> {
        Index<Key>(Ordinal(UInt(position)))
    }

    mutating func freshKey() -> Key {
        let key = Key(id: nextID, collisionDivisor: collisionDivisor)
        nextID += 1
        return key
    }

    mutating func retire(_ id: Int, _ group: Int) {
        graveyard.append((id, group))
        if graveyard.count > 8 { graveyard.removeFirst(graveyard.count - 8) }
    }

    mutating func admit(_ key: Key) -> Bool {
        let inserted = table.insert(
            position: positionIndex(nextPosition),
            hashValue: typedHash(key),
            equals: { _ in false }
        )
        if inserted {
            liveIDs.append(key.id)
            byID[key.id] = (key.group, nextPosition)
            nextPosition += 1
        }
        return inserted
    }

    mutating func insertFresh() {
        let key = freshKey()
        verdict.record("insert id=\(key.id) g=\(key.group) @\(nextPosition)")
        if !admit(key) {
            verdict.diverged(["checked insert of fresh id \(key.id) reported duplicate"])
        }
    }

    mutating func insertDuplicate() {
        let id = liveIDs[rng.below(liveIDs.count)]
        guard let entry = byID[id] else {
            verdict.diverged(["model lost id \(id)"])
            return
        }
        verdict.record("dup id=\(id)")
        let occupant = positionIndex(entry.position)
        let inserted = table.insert(
            position: positionIndex(nextPosition),
            hashValue: typedHash(Key(id: id, group: entry.group)),
            equals: { $0 == occupant }
        )
        if inserted {
            verdict.diverged(["duplicate id \(id) was inserted by the checked door"])
        }
    }

    mutating func removePresent() {
        let pick = rng.below(liveIDs.count)
        let id = liveIDs[pick]
        guard let entry = byID[id] else {
            verdict.diverged(["model lost id \(id)"])
            return
        }
        verdict.record("remove id=\(id) @\(entry.position)")
        let occupant = positionIndex(entry.position)
        let removed = table.remove(
            hashValue: typedHash(Key(id: id, group: entry.group)),
            equals: { $0 == occupant }
        )
        if removed != occupant {
            verdict.diverged(["remove(id \(id)) returned \(String(describing: removed)), model \(entry.position)"])
        }
        liveIDs.remove(at: pick)
        byID[id] = nil
        retire(id, entry.group)
    }

    mutating func removeAbsent() {
        let key = freshKey()
        verdict.record("absent id=\(key.id)")
        let removed = table.remove(hashValue: typedHash(key), equals: { _ in false })
        if removed != nil {
            verdict.diverged(["remove of never-inserted id \(key.id) returned \(String(describing: removed))"])
        }
    }

    mutating func lookupHit() {
        let id = liveIDs[rng.below(liveIDs.count)]
        guard let entry = byID[id] else {
            verdict.diverged(["model lost id \(id)"])
            return
        }
        verdict.record("find id=\(id)")
        let expected = positionIndex(entry.position)
        let found = table.position(forHash: typedHash(Key(id: id, group: entry.group))) { $0 == expected }
        if found != expected {
            verdict.diverged(["lookup(id \(id)): \(String(describing: found)), model \(entry.position)"])
        }
    }

    mutating func lookupMiss() {
        let key = freshKey()
        verdict.record("miss id=\(key.id)")
        let found = table.position(forHash: typedHash(key), equals: { _ in false })
        if found != nil {
            verdict.diverged(["never-inserted id \(key.id) resolved to \(String(describing: found))"])
        }
    }

    mutating func growthBurst() {
        let first = nextID
        for _ in 0..<12 {
            let key = freshKey()
            if !admit(key) {
                verdict.diverged(["burst insert of fresh id \(key.id) reported duplicate"])
                return
            }
        }
        verdict.record("burst ×12 ids \(first)..\(nextID - 1)")
    }

    mutating func wipe() {
        let keep = rng.chance(50)
        verdict.record("wipe keep=\(keep)")
        table.remove.all(keepingCapacity: keep)
        for id in liveIDs.prefix(4) {
            if let entry = byID[id] { retire(id, entry.group) }
        }
        liveIDs.removeAll()
        byID.removeAll()
    }

    func audit() -> [String] {
        var findings: [String] = []
        let count = table.count
        if count != Index<Key>.Count(UInt(liveIDs.count)) {
            findings.append("engine count \(count), model \(liveIDs.count)")
        }
        for id in liveIDs {
            guard let entry = byID[id] else { continue }
            let expected = positionIndex(entry.position)
            let found = table.position(forHash: typedHash(Key(id: id, group: entry.group))) { $0 == expected }
            if found != expected {
                findings.append("live id \(id): position \(String(describing: found)), model \(entry.position)")
            }
        }
        for retired in graveyard where byID[retired.id] == nil {
            let ghost = table.position(forHash: typedHash(Key(id: retired.id, group: retired.group))) { _ in false }
            if ghost != nil {
                findings.append("retired id \(retired.id) still resolves to \(String(describing: ghost))")
            }
        }
        var bucket: Hash.Table<Key>.Bucket.Index = .zero
        let end = table.capacity.map(Ordinal.init)
        var liveBuckets = 0
        while bucket < end {
            if table[hash: bucket] != Hash.Table<Key>.empty { liveBuckets += 1 }
            bucket = bucket.successor.saturating()
        }
        if liveBuckets != liveIDs.count {
            findings.append("\(liveBuckets) occupied buckets, model \(liveIDs.count) (tombstone-free: occupied == count)")
        }
        return findings
    }

    mutating func step() {
        var branch = rng.below(100)
        if liveIDs.isEmpty, branch >= 34 { branch = 0 }
        switch branch {
        case 0..<34: insertFresh()
        case 34..<42: insertDuplicate()
        case 42..<62: removePresent()
        case 62..<66: removeAbsent()
        case 66..<86: lookupHit()
        case 86..<94: lookupMiss()
        case 94..<98: growthBurst()
        default: wipe()
        }
    }

    mutating func run() {
        let operations = Model.operations(default: 1_000)
        var op = 0
        while op < operations, verdict.isClean {
            step()
            if Model.shouldAudit(op: op, of: operations) {
                verdict.diverged(audit())
            }
            op += 1
        }
    }

    consuming func finish() -> Model.Verdict {
        verdict
    }
}

private func runEngineStream(seed: UInt64) -> Model.Verdict {
    var stream = EngineStream(seed: seed)
    stream.run()
    return stream.finish()
}

// MARK: - The move-only stream: exact teardown accounting (every mint dies once)
// (The teardown recorder + the tracked element are the hoisted Model fixtures —
// W3-0; the hashed key bound stays a consumer-side conformance: equality binds
// to `id`, hashing to `group`, hash coarser than equality = lawful collisions.)

extension Model.Element.Tracked: @retroactive Hash.`Protocol` {
    /// Combines the element's group into the hasher.
    public borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(group)
    }

    /// Compares two tracked elements by identity.
    public static func == (lhs: borrowing Model.Element.Tracked, rhs: borrowing Model.Element.Tracked) -> Bool {
        lhs.id == rhs.id
    }
}

private struct TrackedStream: ~Copyable {
    var column: OrderedColumn<Model.Element.Tracked>
    var members: [(id: Int, group: Int)] = []
    var rng: Model.Random
    var verdict: Model.Verdict
    var nextID = 0
    let collisionDivisor = 4
    let census: Model.Census

    init(seed: UInt64, census: Model.Census) {
        var rng = Model.Random(seed: seed)
        self.column = OrderedColumn<Model.Element.Tracked>(minimumCapacity: Index<Model.Element.Tracked>.Count(UInt(rng.below(9))))
        self.rng = rng
        self.verdict = Model.Verdict(seed: seed)
        self.census = census
    }

    mutating func freshID() -> (id: Int, group: Int) {
        let minted = (nextID, nextID / collisionDivisor)
        nextID += 1
        return minted
    }

    func probe(_ member: (id: Int, group: Int)) -> Model.Element.Tracked {
        Model.Element.Tracked(id: member.id, group: member.group, census: census)
    }

    mutating func insertFresh() {
        let minted = freshID()
        verdict.record("insert id=\(minted.id) g=\(minted.group)")
        if let rejected = column.insert(probe(minted)) {
            verdict.diverged(["insert of fresh id \(rejected.id) was rejected as a duplicate"])
        } else {
            members.append(minted)
        }
    }

    mutating func insertDuplicate() {
        let pick = members[rng.below(members.count)]
        verdict.record("dup id=\(pick.id)")
        if let rejected = column.insert(probe(pick)) {
            if rejected.id != pick.id {
                verdict.diverged(["duplicate hand-back id \(rejected.id), expected \(pick.id)"])
            }
        } else {
            verdict.diverged(["duplicate id \(pick.id) was inserted as fresh"])
        }
    }

    mutating func removePresent() {
        let index = rng.below(members.count)
        let pick = members[index]
        verdict.record("remove id=\(pick.id) @\(index)")
        if let removed = column.remove(probe(pick)) {
            if removed.id != pick.id {
                verdict.diverged(["remove(id \(pick.id)) returned id \(removed.id)"])
            }
            members.remove(at: index)
        } else {
            verdict.diverged(["remove(id \(pick.id)) found nothing for a live member"])
        }
    }

    mutating func removeAbsent() {
        let minted = freshID()
        verdict.record("absent id=\(minted.id)")
        if let removed = column.remove(probe(minted)) {
            verdict.diverged(["remove of never-inserted id \(minted.id) returned id \(removed.id)"])
        }
    }

    mutating func containsHit() {
        let pick = members[rng.below(members.count)]
        verdict.record("has id=\(pick.id)")
        if !column.contains(probe(pick)) {
            verdict.diverged(["live id \(pick.id) is not contained"])
        }
    }

    mutating func containsMiss() {
        let minted = freshID()
        verdict.record("miss id=\(minted.id)")
        if column.contains(probe(minted)) {
            verdict.diverged(["never-inserted id \(minted.id) is contained"])
        }
    }

    mutating func positionHit() {
        let index = rng.below(members.count)
        let pick = members[index]
        verdict.record("pos id=\(pick.id) @\(index)")
        let position = column.position(of: probe(pick))
        if position != Index<Model.Element.Tracked>(Ordinal(UInt(index))) {
            verdict.diverged(["position(of: id \(pick.id)): \(String(describing: position)), model \(index)"])
        }
    }

    mutating func mutateRehash() {
        let index = rng.below(members.count)
        let old = members[index]
        let minted = freshID()
        verdict.record("mutate@\(index) \(old.id)→\(minted.id) g\(old.group)→g\(minted.group)")
        column[Index<Model.Element.Tracked>(Ordinal(UInt(index)))] = probe(minted)
        members[index] = minted
    }

    mutating func growthBurst() {
        let first = nextID
        for _ in 0..<8 {
            let minted = freshID()
            if let rejected = column.insert(probe(minted)) {
                verdict.diverged(["burst insert of fresh id \(rejected.id) was rejected"])
                return
            }
            members.append(minted)
        }
        verdict.record("burst ×8 ids \(first)..\(nextID - 1)")
    }

    mutating func wipe() {
        let keep = rng.chance(50)
        verdict.record("wipe keep=\(keep)")
        column.removeAll(keepingCapacity: keep)
        members.removeAll()
    }

    func audit() -> [String] {
        var findings: [String] = []
        let count = column.count
        if count != Index<Model.Element.Tracked>.Count(UInt(members.count)) {
            findings.append("count: column \(count), model \(members.count)")
        }
        for (offset, member) in members.enumerated() {
            let slot = Index<Model.Element.Tracked>(Ordinal(UInt(offset)))
            let resident = column[slot].id
            if resident != member.id {
                findings.append("slot \(offset): column holds id \(resident), model id \(member.id)")
            }
            let position = column.position(of: probe(member))
            if position != slot {
                findings.append("position(of: id \(member.id)): \(String(describing: position)), model slot \(offset)")
            }
        }
        return findings
    }

    mutating func step() {
        var branch = rng.below(100)
        if members.isEmpty, branch >= 30 { branch = 0 }
        switch branch {
        case 0..<30: insertFresh()
        case 30..<38: insertDuplicate()
        case 38..<58: removePresent()
        case 58..<62: removeAbsent()
        case 62..<76: containsHit()
        case 76..<80: containsMiss()
        case 80..<86: positionHit()
        case 86..<94: mutateRehash()
        case 94..<98: growthBurst()
        default: wipe()
        }
    }

    mutating func run() {
        let operations = Model.operations(default: 600)
        var op = 0
        while op < operations, verdict.isClean {
            step()
            if Model.shouldAudit(op: op, of: operations) {
                verdict.diverged(audit())
            }
            op += 1
        }
    }

    consuming func finish() -> Model.Verdict {
        verdict
    }
}

private func runTrackedStream(seed: UInt64) -> Model.Verdict {
    let census = Model.Census()
    var stream = TrackedStream(seed: seed, census: census)
    stream.run()
    var verdict = stream.finish()  // consumes the stream: the column tears down here

    if census.born.sorted() != census.died.sorted() {
        verdict.findings.append(
            "teardown inexact: \(census.born.count) born, \(census.died.count) died"
        )
    }
    return verdict
}

// MARK: - The suites

@Suite
struct `Hash.Indexed Model` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Hash.Indexed Model`.Integration {
    @Test(arguments: Model.seeds(default: [0x5EED_0001, 0xC0FF_EE42, 0xDECA_DE77]))
    func `ordered column op stream matches the reference model under forced collisions`(seed: UInt64) {
        let verdict = runOrderedStream(seed: seed, collisionDivisor: 4)
        #expect(verdict.isClean, Comment(rawValue: verdict.report))
    }

    @Test(arguments: Model.seeds(default: [0x0DD5_EED5, 0xFACE_FEED, 0x1234_5678]))
    func `ordered column op stream matches the reference model with unique hashes`(seed: UInt64) {
        let verdict = runOrderedStream(seed: seed, collisionDivisor: 1)
        #expect(verdict.isClean, Comment(rawValue: verdict.report))
    }

    @Test(arguments: Model.seeds(default: [0xE291_0E01, 0xBADC_0DE5, 0x7AB1_E777]))
    func `bare engine op stream matches the position-map reference model`(seed: UInt64) {
        let verdict = runEngineStream(seed: seed)
        #expect(verdict.isClean, Comment(rawValue: verdict.report))
    }

    @Test(arguments: Model.seeds(default: [0x7EAC_0FF1, 0xD1ED_01CE]))
    func `move-only op stream stays equivalent and tears down exactly`(seed: UInt64) {
        let verdict = runTrackedStream(seed: seed)
        #expect(verdict.isClean, Comment(rawValue: verdict.report))
    }
}

extension `Hash.Indexed Model`.Unit {
    @Test
    func `two instances, same ops: the lawful surface is seed-independent`() {
        var first = OrderedColumn<Key>(minimumCapacity: Index<Key>.Count(8))
        var second = OrderedColumn<Key>(minimumCapacity: Index<Key>.Count(8))
        var members: [Key] = []

        for id in 0..<48 {
            let key = Key(id: id, collisionDivisor: 3)
            first.insert(Key(id: key.id, group: key.group))
            second.insert(Key(id: key.id, group: key.group))
            members.append(key)
        }
        for id in stride(from: 0, to: 48, by: 4).reversed() {
            _ = first.remove(members[id])
            _ = second.remove(members[id])
            members.remove(at: id)
        }

        let counts = (first.count, second.count)
        #expect(counts.0 == counts.1)
        #expect(counts.0 == Index<Key>.Count(UInt(members.count)))
        for (offset, member) in members.enumerated() {
            let slot = Index<Key>(Ordinal(UInt(offset)))
            let residentFirst = first[slot].id
            let residentSecond = second[slot].id
            #expect(residentFirst == member.id)
            #expect(residentSecond == member.id)
            let positionFirst = first.position(of: member)
            let positionSecond = second.position(of: member)
            #expect(positionFirst == slot)
            #expect(positionSecond == slot)
        }
        let coherentFirst = Hash.Coherence.violations(first)
        let coherentSecond = Hash.Coherence.violations(second)
        #expect(coherentFirst.isEmpty, "\(coherentFirst)")
        #expect(coherentSecond.isEmpty, "\(coherentSecond)")
    }

    @Test
    func `growth re-seeds; every live member stays findable in insertion order`() {
        var column = OrderedColumn<Key>(minimumCapacity: .zero)
        for id in 0..<200 {
            column.insert(Key(id: id, collisionDivisor: 5))
        }
        let count = column.count
        #expect(count == Index<Key>.Count(200))
        for id in 0..<200 {
            let position = column.position(of: Key(id: id, collisionDivisor: 5))
            #expect(position == Index<Key>(Ordinal(UInt(id))))
        }
        var seen: [Int] = []
        column.forEach { seen.append($0.id) }
        #expect(seen == Array(0..<200))
        let coherent = Hash.Coherence.violations(column)
        #expect(coherent.isEmpty, "\(coherent)")
    }
}

extension `Hash.Indexed Model`.`Edge Case` {
    @Test
    func `empty column: misses, absent removals, wipes, coherence`() {
        var column = OrderedColumn<Key>(minimumCapacity: Index<Key>.Count(4))
        let absent = Key(id: 7, group: 1)
        let contained = column.contains(absent)
        #expect(!contained)
        let position = column.position(of: absent)
        #expect(position == nil)
        let removed = column.remove(absent)
        #expect(removed == nil)
        column.removeAll(keepingCapacity: true)
        column.removeAll(keepingCapacity: false)
        let count = column.count
        #expect(count == Index<Key>.Count(0))
        let coherent = Hash.Coherence.violations(column)
        #expect(coherent.isEmpty, "\(coherent)")
        column.insert(absent)
        let revived = column.contains(absent)
        #expect(revived)
    }

    @Test
    func `duplicate hand-back returns the argument instance, never the member`() {
        let census = Model.Census()
        do {
            var column = OrderedColumn<Model.Element.Tracked>(minimumCapacity: Index<Model.Element.Tracked>.Count(4))
            column.insert(Model.Element.Tracked(id: 1, group: 0, census: census))  // serial 0: the member
            if let rejected = column.insert(Model.Element.Tracked(id: 1, group: 0, census: census)) {  // serial 1
                let serial = rejected.serial
                #expect(serial == 1)
            } else {
                Issue.record("expected the duplicate to be handed back")
            }
            let diedMid = census.died.sorted()
            #expect(diedMid == [1])  // the argument died; the member lives
            let stillContained = column.contains(Model.Element.Tracked(id: 1, group: 0, census: census))
            #expect(stillContained)
        }
        let born = census.born.sorted()
        let died = census.died.sorted()
        #expect(born == died)  // exactness over the whole scope
    }

    @Test
    func `single-element column: both mutate branches stay coherent`() {
        var column = OrderedColumn<Key>(minimumCapacity: Index<Key>.Count(2))
        column.insert(Key(id: 10, group: 3))
        let slot = Index<Key>(Ordinal(UInt(0)))

        column[slot] = Key(id: 11, group: 3)  // same group: the no-re-index branch
        let oldGone = column.contains(Key(id: 10, group: 3))
        let newFound = column.position(of: Key(id: 11, group: 3))
        #expect(!oldGone)
        #expect(newFound == slot)
        let coherentSame = Hash.Coherence.violations(column)
        #expect(coherentSame.isEmpty, "\(coherentSame)")

        column[slot] = Key(id: 12, group: 9)  // hash change: the re-index branch
        let elevenGone = column.contains(Key(id: 11, group: 3))
        let twelveFound = column.position(of: Key(id: 12, group: 9))
        #expect(!elevenGone)
        #expect(twelveFound == slot)
        let coherentChanged = Hash.Coherence.violations(column)
        #expect(coherentChanged.isEmpty, "\(coherentChanged)")
    }
}
