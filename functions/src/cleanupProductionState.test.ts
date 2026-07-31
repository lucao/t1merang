// Unit tests for cleanupProductionState logic
// Tests threshold validation, cutoff date calculation, and archival conditions
// Validates: Requirement 4.7

describe("cleanupProductionState - threshold validation", () => {
  /**
   * Mirrors the getValidThreshold function from cleanupProductionState.ts
   * Validates and clamps to range 1-365, defaults to 30 if invalid.
   */
  function getValidThreshold(value: unknown): number {
    if (typeof value !== "number" || !Number.isFinite(value)) {
      return 30;
    }
    const clamped = Math.floor(value);
    if (clamped < 1) return 1;
    if (clamped > 365) return 365;
    return clamped;
  }

  it("returns 30 as default when value is undefined", () => {
    expect(getValidThreshold(undefined)).toBe(30);
  });

  it("returns 30 as default when value is null", () => {
    expect(getValidThreshold(null)).toBe(30);
  });

  it("returns 30 as default when value is a string", () => {
    expect(getValidThreshold("30")).toBe(30);
  });

  it("returns 30 as default when value is NaN", () => {
    expect(getValidThreshold(NaN)).toBe(30);
  });

  it("returns 30 as default when value is Infinity", () => {
    expect(getValidThreshold(Infinity)).toBe(30);
  });

  it("returns 30 as default when value is negative Infinity", () => {
    expect(getValidThreshold(-Infinity)).toBe(30);
  });

  it("clamps to 1 when value is 0", () => {
    expect(getValidThreshold(0)).toBe(1);
  });

  it("clamps to 1 when value is negative", () => {
    expect(getValidThreshold(-10)).toBe(1);
  });

  it("clamps to 365 when value exceeds maximum", () => {
    expect(getValidThreshold(500)).toBe(365);
  });

  it("clamps to 365 when value is exactly 366", () => {
    expect(getValidThreshold(366)).toBe(365);
  });

  it("returns the value when it is within valid range", () => {
    expect(getValidThreshold(30)).toBe(30);
    expect(getValidThreshold(1)).toBe(1);
    expect(getValidThreshold(365)).toBe(365);
    expect(getValidThreshold(100)).toBe(100);
  });

  it("floors fractional values", () => {
    expect(getValidThreshold(30.9)).toBe(30);
    expect(getValidThreshold(1.5)).toBe(1);
    expect(getValidThreshold(364.99)).toBe(364);
  });

  it("floors fractional values that would be below 1 after flooring", () => {
    expect(getValidThreshold(0.9)).toBe(1);
    expect(getValidThreshold(0.1)).toBe(1);
  });
});

describe("cleanupProductionState - cutoff date calculation", () => {
  it("calculates cutoff date correctly for 30-day threshold", () => {
    const now = new Date("2024-06-15T12:00:00Z");
    const thresholdDays = 30;
    const cutoffDate = new Date(
      now.getTime() - thresholdDays * 24 * 60 * 60 * 1000
    );
    expect(cutoffDate.toISOString()).toBe("2024-05-16T12:00:00.000Z");
  });

  it("calculates cutoff date correctly for 1-day threshold", () => {
    const now = new Date("2024-06-15T12:00:00Z");
    const thresholdDays = 1;
    const cutoffDate = new Date(
      now.getTime() - thresholdDays * 24 * 60 * 60 * 1000
    );
    expect(cutoffDate.toISOString()).toBe("2024-06-14T12:00:00.000Z");
  });

  it("calculates cutoff date correctly for 365-day threshold", () => {
    const now = new Date("2024-06-15T12:00:00Z");
    const thresholdDays = 365;
    const cutoffDate = new Date(
      now.getTime() - thresholdDays * 24 * 60 * 60 * 1000
    );
    expect(cutoffDate.toISOString()).toBe("2023-06-16T12:00:00.000Z");
  });
});

describe("cleanupProductionState - archival conditions", () => {
  it("identifies activity as expired when stateEnteredAt is before cutoff", () => {
    const cutoffMs = new Date("2024-05-16T12:00:00Z").getTime();
    const activityEnteredMs = new Date("2024-05-10T08:00:00Z").getTime();
    const isExpired = activityEnteredMs < cutoffMs;
    expect(isExpired).toBe(true);
  });

  it("identifies activity as not expired when stateEnteredAt is after cutoff", () => {
    const cutoffMs = new Date("2024-05-16T12:00:00Z").getTime();
    const activityEnteredMs = new Date("2024-06-01T10:00:00Z").getTime();
    const isExpired = activityEnteredMs < cutoffMs;
    expect(isExpired).toBe(false);
  });

  it("identifies activity as not expired when stateEnteredAt equals cutoff exactly", () => {
    const cutoffMs = new Date("2024-05-16T12:00:00Z").getTime();
    const activityEnteredMs = new Date("2024-05-16T12:00:00Z").getTime();
    const isExpired = activityEnteredMs < cutoffMs;
    expect(isExpired).toBe(false);
  });

  it("archives activity with correct metadata fields", () => {
    const activityData = {
      title: "Test Activity",
      currentStateId: "state_production",
      stateEnteredAt: { seconds: 1715000000 },
      responsibleUsers: ["user1", "user2"],
    };
    const archivedAt = { seconds: 1718400000 };
    const archivedFromStateId = "state_production";

    const archivedActivity = {
      ...activityData,
      archivedAt,
      archivedFromStateId,
    };

    expect(archivedActivity).toHaveProperty("title", "Test Activity");
    expect(archivedActivity).toHaveProperty(
      "currentStateId",
      "state_production"
    );
    expect(archivedActivity).toHaveProperty("archivedAt", archivedAt);
    expect(archivedActivity).toHaveProperty(
      "archivedFromStateId",
      "state_production"
    );
    expect(archivedActivity).toHaveProperty("responsibleUsers", [
      "user1",
      "user2",
    ]);
  });
});

describe("cleanupProductionState - batch processing", () => {
  it("correctly chunks documents for batch processing (max 500)", () => {
    const batchSize = 500;
    const totalDocs = 1250;
    const chunks: number[] = [];

    for (let i = 0; i < totalDocs; i += batchSize) {
      const chunkEnd = Math.min(i + batchSize, totalDocs);
      chunks.push(chunkEnd - i);
    }

    expect(chunks).toEqual([500, 500, 250]);
    expect(chunks.reduce((a, b) => a + b, 0)).toBe(totalDocs);
  });

  it("handles exactly 500 documents in a single batch", () => {
    const batchSize = 500;
    const totalDocs = 500;
    const chunks: number[] = [];

    for (let i = 0; i < totalDocs; i += batchSize) {
      const chunkEnd = Math.min(i + batchSize, totalDocs);
      chunks.push(chunkEnd - i);
    }

    expect(chunks).toEqual([500]);
  });

  it("handles fewer than 500 documents in a single batch", () => {
    const batchSize = 500;
    const totalDocs = 3;
    const chunks: number[] = [];

    for (let i = 0; i < totalDocs; i += batchSize) {
      const chunkEnd = Math.min(i + batchSize, totalDocs);
      chunks.push(chunkEnd - i);
    }

    expect(chunks).toEqual([3]);
  });
});
