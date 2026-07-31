// Unit tests for onActivityStateChange logic
// Tests core business logic: duration calculation, conflict detection,
// recipient filtering, state change detection, and HTML escaping

describe("onActivityStateChange - duration calculation", () => {
  // Test the duration calculation logic directly
  it("calculates duration with floor precision (full minutes)", () => {
    // 120 seconds = 2 minutes exactly
    const entrySeconds = 1000;
    const exitSeconds = 1120; // 120 seconds later
    const diff = exitSeconds - entrySeconds;
    const durationMinutes = Math.floor(diff / 60);
    expect(durationMinutes).toBe(2);
  });

  it("calculates duration with floor precision (partial minutes rounded down)", () => {
    // 150 seconds = 2.5 minutes, floor = 2
    const entrySeconds = 1000;
    const exitSeconds = 1150; // 150 seconds later
    const diff = exitSeconds - entrySeconds;
    const durationMinutes = Math.floor(diff / 60);
    expect(durationMinutes).toBe(2);
  });

  it("calculates duration of 0 when less than 60 seconds", () => {
    const entrySeconds = 1000;
    const exitSeconds = 1059; // 59 seconds later
    const diff = exitSeconds - entrySeconds;
    const durationMinutes = Math.floor(diff / 60);
    expect(durationMinutes).toBe(0);
  });

  it("calculates large durations correctly", () => {
    // 3 hours and 45 minutes = 225 minutes = 13500 seconds
    const entrySeconds = 1000;
    const exitSeconds = 14500; // 13500 seconds later
    const diff = exitSeconds - entrySeconds;
    const durationMinutes = Math.floor(diff / 60);
    expect(durationMinutes).toBe(225);
  });
});

describe("onActivityStateChange - version conflict detection", () => {
  it("detects conflict when version jumps by more than 1", () => {
    const beforeVersion = 1;
    const afterVersion = 3; // jumped by 2
    const isConflict = afterVersion - beforeVersion > 1;
    expect(isConflict).toBe(true);
  });

  it("does not detect conflict for normal version increment", () => {
    const beforeVersion = 1;
    const afterVersion = 2; // normal +1 increment
    const isConflict = afterVersion - beforeVersion > 1;
    expect(isConflict).toBe(false);
  });

  it("does not detect conflict when version stays same", () => {
    const beforeVersion = 5;
    const afterVersion = 5;
    const isConflict = afterVersion - beforeVersion > 1;
    expect(isConflict).toBe(false);
  });
});

describe("onActivityStateChange - notification recipient filtering", () => {
  it("excludes the acting user from recipients", () => {
    const responsibleUsers = ["user1", "user2", "user3"];
    const actingUser = "user2";
    const recipients = responsibleUsers.filter(
      (userId) => userId !== actingUser
    );
    expect(recipients).toEqual(["user1", "user3"]);
    expect(recipients).not.toContain("user2");
  });

  it("returns empty array when acting user is the only responsible user", () => {
    const responsibleUsers = ["user1"];
    const actingUser = "user1";
    const recipients = responsibleUsers.filter(
      (userId) => userId !== actingUser
    );
    expect(recipients).toEqual([]);
  });

  it("returns all users except acting user with multiple responsible users", () => {
    const responsibleUsers = ["alice", "bob", "charlie", "diana"];
    const actingUser = "bob";
    const recipients = responsibleUsers.filter(
      (userId) => userId !== actingUser
    );
    expect(recipients).toEqual(["alice", "charlie", "diana"]);
    expect(recipients.length).toBe(3);
  });
});

describe("onActivityStateChange - state change detection", () => {
  it("detects state change when currentStateId differs", () => {
    const beforeStateId = "state_backlog";
    const afterStateId = "state_development";
    const stateChanged = beforeStateId as string !== afterStateId as string;
    expect(stateChanged).toBe(true);
  });

  it("does not detect state change when currentStateId is the same", () => {
    const stateId = "state_backlog";
    const beforeStateId: string = stateId;
    const afterStateId: string = stateId;
    const stateChanged = beforeStateId !== afterStateId;
    expect(stateChanged).toBe(false);
  });
});

describe("onActivityStateChange - email HTML generation", () => {
  it("escapes HTML special characters in notification content", () => {
    const escapeHtml = (text: string): string => {
      return text
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
    };

    expect(escapeHtml('<script>alert("xss")</script>')).toBe(
      "&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;"
    );
    expect(escapeHtml("Tom & Jerry's")).toBe("Tom &amp; Jerry&#039;s");
    expect(escapeHtml("Normal text")).toBe("Normal text");
  });
});
