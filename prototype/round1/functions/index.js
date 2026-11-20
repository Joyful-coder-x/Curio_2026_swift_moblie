const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();
const capacity = 9;

function authenticatedUID(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  return request.auth.uid;
}

exports.publishThread = onCall(async (request) => {
  const creatorUid = authenticatedUID(request);
  const prompt = String(request.data.prompt || "").trim();
  const requestId = String(request.data.requestId || "");
  if (!prompt || prompt.length > 140 || !requestId) {
    throw new HttpsError("invalid-argument", "A prompt and requestId are required.");
  }
  const requestRef = db.doc("users/" + creatorUid + "/requests/" + requestId);
  const threadRef = db.collection("threads").doc();
  return db.runTransaction(async (transaction) => {
    const replay = await transaction.get(requestRef);
    if (replay.exists) return replay.data();
    const publishedAt = Timestamp.now();
    const expiresAt = Timestamp.fromMillis(publishedAt.toMillis() + 600000);
    const result = { threadId: threadRef.id, expiresAt: expiresAt.toMillis() };
    transaction.create(threadRef, {
      creatorUid,
      prompt,
      visibility: request.data.visibility === "private" ? "private" : "public",
      capacity,
      peopleCount: 1,
      status: "open",
      publishedAt,
      expiresAt
    });
    transaction.create(threadRef.collection("contributions").doc(creatorUid), {
      authorUid: creatorUid,
      assetId: String(request.data.assetId || "demo"),
      slot: 1,
      acceptedAt: publishedAt
    });
    transaction.create(db.doc("users/" + creatorUid + "/myThreads/" + threadRef.id), {
      threadId: threadRef.id,
      role: "created",
      acceptedAt: publishedAt
    });
    transaction.create(requestRef, { action: "publishThread", ...result });
    return result;
  });
});

exports.joinThread = onCall(async (request) => {
  const authorUid = authenticatedUID(request);
  const threadId = String(request.data.threadId || "");
  const requestId = String(request.data.requestId || "");
  if (!threadId || !requestId) {
    throw new HttpsError("invalid-argument", "threadId and requestId are required.");
  }
  const threadRef = db.doc("threads/" + threadId);
  const contributionRef = threadRef.collection("contributions").doc(authorUid);
  const requestRef = db.doc("users/" + authorUid + "/requests/" + requestId);
  return db.runTransaction(async (transaction) => {
    const replay = await transaction.get(requestRef);
    if (replay.exists) return replay.data();
    const [threadSnapshot, contributionSnapshot] = await Promise.all([
      transaction.get(threadRef),
      transaction.get(contributionRef)
    ]);
    if (!threadSnapshot.exists) throw new HttpsError("not-found", "Thread not found.");
    const thread = threadSnapshot.data();
    if (Timestamp.now().toMillis() >= thread.expiresAt.toMillis()) {
      throw new HttpsError("deadline-exceeded", "Thread expired.");
    }
    if (thread.peopleCount >= capacity) {
      throw new HttpsError("resource-exhausted", "Thread is full.");
    }
    if (contributionSnapshot.exists) {
      throw new HttpsError("already-exists", "You already joined.");
    }
    const slot = thread.peopleCount + 1;
    const result = { threadId, slot };
    transaction.create(contributionRef, {
      authorUid,
      assetId: String(request.data.assetId || "demo"),
      slot,
      acceptedAt: FieldValue.serverTimestamp()
    });
    transaction.update(threadRef, {
      peopleCount: slot,
      status: slot === capacity ? "full" : "open"
    });
    transaction.create(requestRef, { action: "joinThread", ...result });
    return result;
  });
});

exports.sendMessage = onCall(async (request) => {
  const senderUid = authenticatedUID(request);
  const threadId = String(request.data.threadId || "");
  const requestId = String(request.data.requestId || "");
  const body = String(request.data.body || "").trim();
  if (!body || body.length > 1000 || !requestId) {
    throw new HttpsError("invalid-argument", "A body and requestId are required.");
  }
  const threadRef = db.doc("threads/" + threadId);
  const membershipRef = threadRef.collection("contributions").doc(senderUid);
  const messageRef = threadRef.collection("messages").doc(senderUid + "_" + requestId);
  await db.runTransaction(async (transaction) => {
    const [thread, membership, existing] = await Promise.all([
      transaction.get(threadRef),
      transaction.get(membershipRef),
      transaction.get(messageRef)
    ]);
    if (existing.exists) return;
    if (!thread.exists || !membership.exists) {
      throw new HttpsError("permission-denied", "Only contributors can chat.");
    }
    if (Timestamp.now().toMillis() >= thread.data().expiresAt.toMillis()) {
      throw new HttpsError("deadline-exceeded", "Thread expired.");
    }
    transaction.create(messageRef, {
      senderUid,
      body,
      requestId,
      sentAt: FieldValue.serverTimestamp()
    });
  });
  return { messageId: messageRef.id };
});
