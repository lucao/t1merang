import { determineWinner } from "./conflictResolutionLogic";

/**
 * Unit tests for the conflict resolution determineWinner function.
 *
 * Validates: Requirements 13.7, 13.8, 13.9
 */
describe("determineWinner", () => {
  // Helper to create a mock version
  function makeVersion(
    versionId: string,
    authorId: string,
    modifiedAtMs: number
  ) {
    return {
      versionId,
      value: `value_${versionId}`,
      authorId,
      modifiedAt: { _seconds: Math.floor(modifiedAtMs / 1000), _nanoseconds: 0 },
    };
  }

  describe("Requirement 13.7: Majority vote wins", () => {
    it("should return the version with the most votes", () => {
      const versions = [
        makeVersion("v1", "userA", 1000000),
        makeVersion("v2", "userB", 2000000),
      ];
      const votes = {
        user1: "v1",
        user2: "v1",
        user3: "v2",
      };

      const result = determineWinner(versions, votes);

      expect(result.winningVersion?.versionId).toBe("v1");
      expect(result.resolutionMethod).toBe("consensus");
    });

    it("should handle single vote correctly", () => {
      const versions = [
        makeVersion("v1", "userA", 1000000),
        makeVersion("v2", "userB", 2000000),
      ];
      const votes = { user1: "v2" };

      const result = determineWinner(versions, votes);

      expect(result.winningVersion?.versionId).toBe("v2");
      expect(result.resolutionMethod).toBe("consensus");
    });

    it("should handle multiple versions with clear majority", () => {
      const versions = [
        makeVersion("v1", "userA", 1000000),
        makeVersion("v2", "userB", 2000000),
        makeVersion("v3", "userC", 3000000),
      ];
      const votes = {
        user1: "v2",
        user2: "v2",
        user3: "v3",
        user4: "v1",
        user5: "v2",
      };

      const result = determineWinner(versions, votes);

      expect(result.winningVersion?.versionId).toBe("v2");
      expect(result.resolutionMethod).toBe("consensus");
    });
  });

  describe("Requirement 13.8: Fallback to most recent timestamp when no votes", () => {
    it("should return the version with most recent timestamp when no votes", () => {
      const versions = [
        makeVersion("v1", "userA", 1000000),
        makeVersion("v2", "userB", 3000000),
        makeVersion("v3", "userC", 2000000),
      ];
      const votes = {};

      const result = determineWinner(versions, votes);

      expect(result.winningVersion?.versionId).toBe("v2");
      expect(result.resolutionMethod).toBe("fallback");
    });

    it("should handle single version with no votes", () => {
      const versions = [makeVersion("v1", "userA", 1000000)];
      const votes = {};

      const result = determineWinner(versions, votes);

      expect(result.winningVersion?.versionId).toBe("v1");
      expect(result.resolutionMethod).toBe("fallback");
    });
  });

  describe("Requirement 13.9: Tie-break by most recent timestamp", () => {
    it("should break tie by most recent timestamp among tied versions", () => {
      const versions = [
        makeVersion("v1", "userA", 1000000),
        makeVersion("v2", "userB", 3000000),
      ];
      const votes = {
        user1: "v1",
        user2: "v2",
      };

      const result = determineWinner(versions, votes);

      expect(result.winningVersion?.versionId).toBe("v2");
      expect(result.resolutionMethod).toBe("consensus");
    });

    it("should break multi-way tie by most recent timestamp", () => {
      const versions = [
        makeVersion("v1", "userA", 5000000),
        makeVersion("v2", "userB", 2000000),
        makeVersion("v3", "userC", 7000000),
      ];
      const votes = {
        user1: "v1",
        user2: "v2",
        user3: "v3",
      };

      const result = determineWinner(versions, votes);

      expect(result.winningVersion?.versionId).toBe("v3");
      expect(result.resolutionMethod).toBe("consensus");
    });

    it("should handle tie where older version has fewer votes than tied newer ones", () => {
      const versions = [
        makeVersion("v1", "userA", 1000000),
        makeVersion("v2", "userB", 4000000),
        makeVersion("v3", "userC", 3000000),
      ];
      // v2 and v3 are tied at 2 votes each, v1 has 1
      const votes = {
        user1: "v2",
        user2: "v3",
        user3: "v2",
        user4: "v3",
        user5: "v1",
      };

      const result = determineWinner(versions, votes);

      expect(result.winningVersion?.versionId).toBe("v2");
      expect(result.resolutionMethod).toBe("consensus");
    });
  });

  describe("Edge cases", () => {
    it("should return null winning version for empty versions array", () => {
      const result = determineWinner([], {});

      expect(result.winningVersion).toBeNull();
      expect(result.resolutionMethod).toBe("fallback");
    });

    it("should handle versions with identical timestamps (no votes)", () => {
      const versions = [
        makeVersion("v1", "userA", 1000000),
        makeVersion("v2", "userB", 1000000),
      ];
      const votes = {};

      const result = determineWinner(versions, votes);

      // Either version could win since timestamps are identical
      expect(result.winningVersion).not.toBeNull();
      expect(result.resolutionMethod).toBe("fallback");
    });
  });
});
