/**
 * Pure conflict resolution logic — no Firebase dependencies.
 * Extracted for independent unit testing.
 *
 * Requirements: 13.7, 13.8, 13.9
 */

export interface ConflictVersion {
  versionId: string;
  value: unknown;
  authorId: string;
  modifiedAt: { _seconds: number; _nanoseconds: number } | number | Date | unknown;
}

export interface ResolutionResult {
  winningVersion: ConflictVersion | null;
  resolutionMethod: "consensus" | "fallback";
}

/**
 * Determines the winning version based on vote counts and timestamps.
 *
 * Resolution rules (Req 13.7, 13.8, 13.9):
 * - Version with the most votes wins (consensus)
 * - If no votes cast, version with most recent timestamp wins (fallback)
 * - If tied votes, version with most recent timestamp among tied wins (consensus)
 */
export function determineWinner(
  versions: ConflictVersion[],
  votes: Record<string, string>
): ResolutionResult {
  if (!versions || versions.length === 0) {
    return { winningVersion: null, resolutionMethod: "fallback" };
  }

  const voteEntries = Object.values(votes);

  // If no votes cast, apply fallback: most recent modification timestamp (Req 13.8)
  if (voteEntries.length === 0) {
    const sorted = [...versions].sort((a, b) => {
      return getTimestampMillis(b.modifiedAt) - getTimestampMillis(a.modifiedAt);
    });
    return { winningVersion: sorted[0], resolutionMethod: "fallback" };
  }

  // Count votes per version
  const voteCounts: Record<string, number> = {};
  for (const versionId of voteEntries) {
    voteCounts[versionId] = (voteCounts[versionId] || 0) + 1;
  }

  // Find the maximum vote count
  const maxVotes = Math.max(...Object.values(voteCounts));

  // Get all versions with the max vote count
  const tiedVersionIds = Object.entries(voteCounts)
    .filter(([, count]) => count === maxVotes)
    .map(([versionId]) => versionId);

  // If only one version has the max votes, it wins by consensus (Req 13.7)
  if (tiedVersionIds.length === 1) {
    const winner = versions.find((v) => v.versionId === tiedVersionIds[0]);
    return { winningVersion: winner || null, resolutionMethod: "consensus" };
  }

  // Tie-break: among tied versions, pick the one with most recent timestamp (Req 13.9)
  const tiedVersions = versions.filter((v) =>
    tiedVersionIds.includes(v.versionId)
  );
  const sorted = [...tiedVersions].sort((a, b) => {
    return getTimestampMillis(b.modifiedAt) - getTimestampMillis(a.modifiedAt);
  });

  return { winningVersion: sorted[0], resolutionMethod: "consensus" };
}

/**
 * Extracts milliseconds from a Firestore Timestamp-like object or plain value.
 */
export function getTimestampMillis(ts: unknown): number {
  // Handle serialized timestamp objects { _seconds, _nanoseconds }
  if (ts && typeof ts === "object" && "_seconds" in (ts as Record<string, unknown>)) {
    const obj = ts as { _seconds: number; _nanoseconds: number };
    return obj._seconds * 1000 + Math.floor((obj._nanoseconds || 0) / 1_000_000);
  }
  // Handle Firestore Timestamp with toMillis()
  if (ts && typeof ts === "object" && "toMillis" in (ts as Record<string, unknown>)) {
    return (ts as { toMillis: () => number }).toMillis();
  }
  // Handle Date objects
  if (ts instanceof Date) {
    return ts.getTime();
  }
  // Handle numeric timestamps (milliseconds)
  if (typeof ts === "number") {
    return ts;
  }
  return 0;
}
