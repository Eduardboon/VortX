import Foundation

/// Memoizes a DetailView's ranked-groups + best across SwiftUI body re-evaluations. A detail body re-evaluates on
/// every CoreBridge @Published bump while the source list is open (progress ticks, the settle timer, debrid
/// cache-check results); re-ranking a 1000+ stream list each time starves the main thread (the source-list lag).
/// This recomputes only when the caller's signature (a cheap O(groups) fingerprint of the stream set + pin +
/// debrid cache + ranking prefs + continuity) changes; otherwise it returns the last result untouched.
///
/// Held by a view as @State (NOT @StateObject) on purpose: mutating these fields must NOT go through the @State
/// setter (no "modifying state during view update") and must fire no objectWillChange (a publish would re-render
/// on every cache hit and defeat the memo). Shared by SourcesTV/DetailView and SourcesiOS/iOSDetailView. Depends
/// only on SourcesShared types (CoreStreamSourceGroup, CoreStream, ResolvedPin, StreamRanking) so it compiles for
/// every native Apple target. Main-actor because it is only ever touched from `body`.
@MainActor final class DetailRankMemo {
    private var signature = ""
    private var cachedGroups: [CoreStreamSourceGroup] = []
    private var cachedBest: CoreStream?

    func ranked(_ raw: [CoreStreamSourceGroup], signature sig: String, pin: ResolvedPin?,
                cached: Set<String>, continuity: String?) -> (groups: [CoreStreamSourceGroup], best: CoreStream?) {
        if sig != signature {
            signature = sig
            cachedGroups = StreamRanking.rankedGroups(raw, pin: pin, debridCachedHashes: cached)
            cachedBest = StreamRanking.best(cachedGroups, continuity: continuity, pin: pin, debridCachedHashes: cached)
        }
        return (cachedGroups, cachedBest)
    }
}
