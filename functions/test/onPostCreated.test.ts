import * as admin from "firebase-admin";

// Mock firebase-admin
jest.mock("firebase-admin", () => {
  const firestoreMock = {
    collection: jest.fn(),
  };

  const firestoreFunction = jest.fn(() => firestoreMock) as any;
  firestoreFunction.FieldValue = {
    serverTimestamp: jest.fn(() => "SERVER_TIMESTAMP"),
  };

  return {
    initializeApp: jest.fn(),
    firestore: firestoreFunction,
    apps: [{}],
  };
});

// We need to import after mocking
import { onPostCreated } from "../src/onPostCreated";

// Helper to create a wrapped function for testing
function getWrappedFunction() {
  // firebase-functions-test offline mode
  const testFunctions = require("firebase-functions-test")();
  return testFunctions.wrap(onPostCreated);
}

describe("onPostCreated", () => {
  let wrappedFunction: ReturnType<typeof getWrappedFunction>;
  let firestoreMock: any;
  let collectionMock: jest.Mock;
  let addMock: jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();

    addMock = jest.fn().mockResolvedValue({ id: "notification-id" });

    const activityDoc = {
      exists: true,
      data: () => ({
        title: "Fix login bug",
        responsibleUsers: ["user-1", "user-2", "user-3"],
      }),
    };

    const authorDoc = {
      exists: true,
      data: () => ({
        nickname: "Alice",
      }),
    };

    const docMock = jest.fn().mockImplementation((docId: string) => {
      if (docId.startsWith("activity")) {
        return { get: jest.fn().mockResolvedValue(activityDoc) };
      }
      return { get: jest.fn().mockResolvedValue(authorDoc) };
    });

    const whereMock = jest.fn().mockReturnValue({
      get: jest.fn().mockResolvedValue({ docs: [] }),
    });

    collectionMock = jest.fn().mockImplementation((path: string) => {
      if (path === "notifications") {
        return { add: addMock };
      }
      if (path === "users") {
        return { doc: docMock, where: whereMock };
      }
      return { doc: docMock };
    });

    firestoreMock = (admin.firestore as unknown as jest.Mock)();
    firestoreMock.collection = collectionMock;

    wrappedFunction = getWrappedFunction();
  });

  afterAll(() => {
    const testFunctions = require("firebase-functions-test")();
    testFunctions.cleanup();
  });

  it("should send notifications to responsible users excluding author", async () => {
    const snapshot = {
      data: () => ({
        content: "This is a new post about the login bug",
        category: "Information",
        authorId: "user-1",
        targetSectors: [],
      }),
    };

    const context = {
      params: {
        activityId: "activity-123",
        postId: "post-456",
      },
    };

    await wrappedFunction(snapshot, context);

    // Should send notifications to user-2 and user-3 (not user-1 who is the author)
    expect(addMock).toHaveBeenCalledTimes(2);

    // Check notification for user-2
    expect(addMock).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: "user-2",
        type: "discussion",
        activityId: "activity-123",
        title: 'New post in "Fix login bug"',
        body: "Alice: This is a new post about the login bug",
        read: false,
      })
    );

    // Check notification for user-3
    expect(addMock).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: "user-3",
        type: "discussion",
        activityId: "activity-123",
        title: 'New post in "Fix login bug"',
        body: "Alice: This is a new post about the login bug",
        read: false,
      })
    );
  });

  it("should truncate post content to 200 characters in notification body", async () => {
    const longContent = "A".repeat(250);

    const snapshot = {
      data: () => ({
        content: longContent,
        category: "Information",
        authorId: "user-1",
        targetSectors: [],
      }),
    };

    const context = {
      params: {
        activityId: "activity-123",
        postId: "post-456",
      },
    };

    await wrappedFunction(snapshot, context);

    // Body should contain truncated content (200 chars + "...")
    const expectedBody = `Alice: ${"A".repeat(200)}...`;
    expect(addMock).toHaveBeenCalledWith(
      expect.objectContaining({
        body: expectedBody,
      })
    );
  });

  it("should not truncate content that is exactly 200 characters", async () => {
    const exactContent = "B".repeat(200);

    const snapshot = {
      data: () => ({
        content: exactContent,
        category: "Information",
        authorId: "user-1",
        targetSectors: [],
      }),
    };

    const context = {
      params: {
        activityId: "activity-123",
        postId: "post-456",
      },
    };

    await wrappedFunction(snapshot, context);

    const expectedBody = `Alice: ${"B".repeat(200)}`;
    expect(addMock).toHaveBeenCalledWith(
      expect.objectContaining({
        body: expectedBody,
      })
    );
  });

  it("should send Ask_Help notifications to users in target sectors", async () => {
    const sectorUsersSnapshot = {
      docs: [
        { id: "sector-user-1", data: () => ({ nickname: "Bob", sectorId: "sector-A" }) },
        { id: "sector-user-2", data: () => ({ nickname: "Carol", sectorId: "sector-B" }) },
        { id: "user-1", data: () => ({ nickname: "Alice", sectorId: "sector-A" }) },
      ],
    };

    const whereMock = jest.fn().mockReturnValue({
      get: jest.fn().mockResolvedValue(sectorUsersSnapshot),
    });

    const activityDoc = {
      exists: true,
      data: () => ({
        title: "Fix login bug",
        responsibleUsers: ["user-1", "user-2"],
      }),
    };

    const authorDoc = {
      exists: true,
      data: () => ({
        nickname: "Alice",
      }),
    };

    const docMock = jest.fn().mockImplementation((docId: string) => {
      if (docId === "user-1") {
        return { get: jest.fn().mockResolvedValue(authorDoc) };
      }
      return { get: jest.fn().mockResolvedValue(activityDoc) };
    });

    collectionMock.mockImplementation((path: string) => {
      if (path === "notifications") {
        return { add: addMock };
      }
      if (path === "users") {
        return { doc: docMock, where: whereMock };
      }
      return { doc: docMock };
    });

    const snapshot = {
      data: () => ({
        content: "I need help with sector integration",
        category: "Ask_Help",
        authorId: "user-1",
        targetSectors: ["sector-A", "sector-B"],
      }),
    };

    const context = {
      params: {
        activityId: "activity-123",
        postId: "post-789",
      },
    };

    await wrappedFunction(snapshot, context);

    // user-2 gets "discussion" notification (responsible, not author)
    // sector-user-1 and sector-user-2 get "ask_help" notifications (in target sectors)
    // user-1 (author) should NOT get any notification
    // user-2 (already notified as responsible) should NOT get ask_help notification
    expect(addMock).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: "user-2",
        type: "discussion",
      })
    );

    expect(addMock).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: "sector-user-1",
        type: "ask_help",
        title: 'Help requested in "Fix login bug"',
      })
    );

    expect(addMock).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: "sector-user-2",
        type: "ask_help",
        title: 'Help requested in "Fix login bug"',
      })
    );

    // Total: 1 discussion (user-2) + 2 ask_help (sector-user-1, sector-user-2)
    expect(addMock).toHaveBeenCalledTimes(3);
  });

  it("should not send notifications if activity does not exist", async () => {
    const activityDoc = {
      exists: false,
      data: () => null,
    };

    const docMock = jest.fn().mockReturnValue({
      get: jest.fn().mockResolvedValue(activityDoc),
    });

    collectionMock.mockImplementation((path: string) => {
      if (path === "notifications") {
        return { add: addMock };
      }
      return { doc: docMock };
    });

    const snapshot = {
      data: () => ({
        content: "Test post",
        category: "Information",
        authorId: "user-1",
        targetSectors: [],
      }),
    };

    const context = {
      params: {
        activityId: "nonexistent-activity",
        postId: "post-456",
      },
    };

    await wrappedFunction(snapshot, context);

    expect(addMock).not.toHaveBeenCalled();
  });

  it("should not send any notifications if author is the only responsible user", async () => {
    const activityDoc = {
      exists: true,
      data: () => ({
        title: "Solo activity",
        responsibleUsers: ["user-1"],
      }),
    };

    const authorDoc = {
      exists: true,
      data: () => ({
        nickname: "Alice",
      }),
    };

    const docMock = jest.fn().mockImplementation((docId: string) => {
      if (docId === "user-1") {
        return { get: jest.fn().mockResolvedValue(authorDoc) };
      }
      return { get: jest.fn().mockResolvedValue(activityDoc) };
    });

    collectionMock.mockImplementation((path: string) => {
      if (path === "notifications") {
        return { add: addMock };
      }
      if (path === "users") {
        return { doc: docMock, where: jest.fn().mockReturnValue({ get: jest.fn().mockResolvedValue({ docs: [] }) }) };
      }
      return { doc: docMock };
    });

    const snapshot = {
      data: () => ({
        content: "My post",
        category: "Information",
        authorId: "user-1",
        targetSectors: [],
      }),
    };

    const context = {
      params: {
        activityId: "activity-123",
        postId: "post-456",
      },
    };

    await wrappedFunction(snapshot, context);

    expect(addMock).not.toHaveBeenCalled();
  });

  it("should handle unknown author gracefully", async () => {
    const activityDoc = {
      exists: true,
      data: () => ({
        title: "Team activity",
        responsibleUsers: ["user-1", "user-2"],
      }),
    };

    const unknownAuthorDoc = {
      exists: false,
      data: () => null,
    };

    const docMock = jest.fn().mockImplementation((docId: string) => {
      if (docId === "unknown-user") {
        return { get: jest.fn().mockResolvedValue(unknownAuthorDoc) };
      }
      return { get: jest.fn().mockResolvedValue(activityDoc) };
    });

    collectionMock.mockImplementation((path: string) => {
      if (path === "notifications") {
        return { add: addMock };
      }
      if (path === "users") {
        return { doc: docMock, where: jest.fn().mockReturnValue({ get: jest.fn().mockResolvedValue({ docs: [] }) }) };
      }
      return { doc: docMock };
    });

    const snapshot = {
      data: () => ({
        content: "Ghost post",
        category: "Information",
        authorId: "unknown-user",
        targetSectors: [],
      }),
    };

    const context = {
      params: {
        activityId: "activity-123",
        postId: "post-456",
      },
    };

    await wrappedFunction(snapshot, context);

    // Should still send notifications with "Unknown User" as author name
    expect(addMock).toHaveBeenCalledWith(
      expect.objectContaining({
        body: "Unknown User: Ghost post",
      })
    );
  });
});
