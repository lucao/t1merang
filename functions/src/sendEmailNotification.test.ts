/* eslint-disable @typescript-eslint/no-explicit-any */

// Mock firebase-admin before imports
jest.mock("firebase-admin", () => ({
  initializeApp: jest.fn(),
  firestore: {
    FieldValue: {
      serverTimestamp: jest.fn(() => "SERVER_TIMESTAMP"),
      increment: jest.fn((n: number) => n),
    },
    Timestamp: {
      now: jest.fn(() => ({ toDate: () => new Date() })),
    },
  },
}));

// Mock @sendgrid/mail
const mockSend = jest.fn();
jest.mock("@sendgrid/mail", () => ({
  __esModule: true,
  default: {
    setApiKey: jest.fn(),
    send: (...args: unknown[]) => mockSend(...args),
  },
}));

// Mock firebase-functions
jest.mock("firebase-functions", () => {
  return {
    config: () => ({
      sendgrid: { key: "test-key", from: "test@t1merang.app" },
    }),
    logger: {
      info: jest.fn(),
      warn: jest.fn(),
      error: jest.fn(),
    },
    firestore: {
      document: (path: string) => ({
        onWrite: (handler: any) => {
          // Store the handler so we can call it directly in tests
          (module as any).__handler = handler;
          return handler;
        },
      }),
    },
  };
});

// Import after mocks
import "./sendEmailNotification";

// Get the handler that was registered
function getHandler(): (change: any, context: any) => Promise<any> {
  return (module as any).__handler;
}

describe("sendEmailNotification", () => {
  let handler: (change: any, context: any) => Promise<any>;

  beforeAll(() => {
    handler = getHandler();
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  function makeChange(afterData: any, afterExists = true) {
    const ref = { update: jest.fn().mockResolvedValue(undefined) };
    return {
      before: { exists: false, data: () => null, ref: { update: jest.fn() } },
      after: { exists: afterExists, data: () => afterData, ref },
    };
  }

  function makeContext(emailId: string) {
    return { params: { emailId } };
  }

  it("should do nothing if document is deleted", async () => {
    const change = makeChange(null, false);
    const result = await handler(change, makeContext("email1"));

    expect(result).toBeNull();
    expect(mockSend).not.toHaveBeenCalled();
  });

  it("should skip emails not in pending status", async () => {
    const change = makeChange({
      to: "user@test.com",
      subject: "Test",
      htmlBody: "<p>Hi</p>",
      status: "sent",
      attempts: 1,
      lastAttemptAt: null,
      createdAt: null,
    });
    const result = await handler(change, makeContext("email2"));

    expect(result).toBeNull();
    expect(mockSend).not.toHaveBeenCalled();
  });

  it("should mark as failed if attempts >= 3", async () => {
    const change = makeChange({
      to: "user@test.com",
      subject: "Test",
      htmlBody: "<p>Hi</p>",
      status: "pending",
      attempts: 3,
      lastAttemptAt: null,
      createdAt: null,
    });
    const result = await handler(change, makeContext("email3"));

    expect(result).toBeNull();
    expect(change.after.ref.update).toHaveBeenCalledWith({ status: "failed" });
    expect(mockSend).not.toHaveBeenCalled();
  });

  it("should skip if last attempt was less than 1 minute ago", async () => {
    const change = makeChange({
      to: "user@test.com",
      subject: "Test",
      htmlBody: "<p>Hi</p>",
      status: "pending",
      attempts: 1,
      lastAttemptAt: { toDate: () => new Date() }, // just now
      createdAt: null,
    });
    const result = await handler(change, makeContext("email4"));

    expect(result).toBeNull();
    expect(mockSend).not.toHaveBeenCalled();
    expect(change.after.ref.update).not.toHaveBeenCalled();
  });

  it("should send email and update status to sent on success", async () => {
    mockSend.mockResolvedValueOnce([{ statusCode: 202 }]);

    const change = makeChange({
      to: "user@test.com",
      subject: "State Changed",
      htmlBody: "<p>Activity moved</p>",
      status: "pending",
      attempts: 0,
      lastAttemptAt: null,
      createdAt: null,
    });
    const result = await handler(change, makeContext("email5"));

    expect(result).toBeNull();
    expect(mockSend).toHaveBeenCalledWith({
      to: "user@test.com",
      from: "test@t1merang.app",
      subject: "State Changed",
      html: "<p>Activity moved</p>",
    });
    expect(change.after.ref.update).toHaveBeenCalledWith({
      status: "sent",
      lastAttemptAt: "SERVER_TIMESTAMP",
      attempts: 1,
    });
  });

  it("should increment attempts on failure and keep pending if under max", async () => {
    mockSend.mockRejectedValueOnce(new Error("SendGrid API error"));

    const change = makeChange({
      to: "user@test.com",
      subject: "Test",
      htmlBody: "<p>Hi</p>",
      status: "pending",
      attempts: 1,
      lastAttemptAt: { toDate: () => new Date(Date.now() - 120_000) }, // 2 min ago
      createdAt: null,
    });
    const result = await handler(change, makeContext("email6"));

    expect(result).toBeNull();
    expect(change.after.ref.update).toHaveBeenCalledWith({
      attempts: 2,
      lastAttemptAt: "SERVER_TIMESTAMP",
    });
    // Status should NOT be set to failed (only 2nd attempt)
    expect(change.after.ref.update).not.toHaveBeenCalledWith(
      expect.objectContaining({ status: "failed" })
    );
  });

  it("should mark as failed on third failed attempt", async () => {
    mockSend.mockRejectedValueOnce(new Error("SendGrid timeout"));

    const change = makeChange({
      to: "user@test.com",
      subject: "Test",
      htmlBody: "<p>Hi</p>",
      status: "pending",
      attempts: 2,
      lastAttemptAt: { toDate: () => new Date(Date.now() - 120_000) }, // 2 min ago
      createdAt: null,
    });
    const result = await handler(change, makeContext("email7"));

    expect(result).toBeNull();
    expect(change.after.ref.update).toHaveBeenCalledWith({
      attempts: 3,
      lastAttemptAt: "SERVER_TIMESTAMP",
      status: "failed",
    });
  });

  it("should process email when lastAttemptAt is older than 1 minute", async () => {
    mockSend.mockResolvedValueOnce([{ statusCode: 202 }]);

    const change = makeChange({
      to: "user@test.com",
      subject: "Retry Test",
      htmlBody: "<p>Retry</p>",
      status: "pending",
      attempts: 1,
      lastAttemptAt: { toDate: () => new Date(Date.now() - 90_000) }, // 1.5 min ago
      createdAt: null,
    });
    const result = await handler(change, makeContext("email8"));

    expect(result).toBeNull();
    expect(mockSend).toHaveBeenCalled();
    expect(change.after.ref.update).toHaveBeenCalledWith({
      status: "sent",
      lastAttemptAt: "SERVER_TIMESTAMP",
      attempts: 1,
    });
  });
});
