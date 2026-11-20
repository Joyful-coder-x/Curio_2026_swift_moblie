# Curio · First prototype assignment

**Goal:** On two independent iOS clients, one user starts a thread and another joins with a photo. They can chat, reopen the same journal and see their own photo in the center. Use three test accounts: A creates, B contributes, C observes. Use seeded accounts for capacity tests. This is an implementation brief with a runnable SQL reference and draft Firebase rules.

## Build four small views

1. **Home:** one list of open invitations plus My Threads; use a single seeded thread or a recent-first query. Remove full/expired threads from discovery. Keep a stable detail route by ID.
2. **Photo form (reuse for create and join):** capture/select, review or retake, show that accepted photos are permanent. Creator enters a short prompt. Submit, wait for server acceptance, then open the thread. Preserve the local draft on failure.
3. **Thread:** show prompt, photo tiles, count including creator and time remaining. Show Join to eligible visitors; text conversation to members. At 9/9 joining ends while chat remains available until expiry.
4. **Journal:** at expiry open the same ID read-only. Prompt, 3×3 photo cover, contributor list, member-only chat history. Put the current contributor in cell 5, put remaining photos in acceptance order and leave unused cells empty. For visitors use the creator in cell 5. Visitor layout and empty cells are prototype defaults.

Defer following/recommendations, notification delivery, ranking, QR generation, profile design and media attachments in chat. Text chat and authenticated photo access are in scope. Use the existing one-publication-per-day rule with UTC as a test default.

## Firebase contract

Use Firebase Auth UIDs. Firestore holds structured records. Cloud Storage holds JPEG bytes. For the first round, the journal is a read-only presentation of the same thread, contributions and messages. This keeps shared links and contributor-specific layouts independent of duplicate copies.

| Path | Fields and ownership |
|---|---|
| threads/{t} | creatorUid, prompt, publishedAt, expiresAt (= publishedAt + 12h), capacity=9, peopleCount starting at 1, status=open/full/archived. Signed-in readable; published records only. |
| threads/{t}/contributions/{uid} | authorUid, assetId, slot=1..9, acceptedAt. The creator owns slot 1. Existence grants member chat access, including archival reads. Immutable. |
| threads/{t}/messages/{id} | senderUid, body, sentAt, requestId. Server verifies caller has a contribution and current server time is before expiresAt. Author/request-scoped deterministic ID prevents retry duplicates. Readable only by members. |
| users/{uid}/myThreads/{t} | threadId, role=created/joined, acceptedAt. Only this user can read their index. |
| daily/{uid}/days/{utcDate} | threadId. Server-only unique publication guard, created atomically with the thread. |
| assets/{assetId} | ownerUid, threadId, kind, state=pending/committed/deleting, expiresAt, object generation and verified metadata. Owner may fetch own metadata. Server writes. |
| photos/{uid}/{assetId}/photo.jpg (Storage) | Create once against a live, server-issued pending asset; authenticated SDK reads by path. Pending reads owner-only; committed photos readable by any signed-in user. No client overwrite, delete or list. |
| users/{uid}/requests/{key} | Server-only idempotency record containing action, normalized input fingerprint, and resulting IDs. |

**Write sequence:** (1) An authenticated prepare callable allocates a pending asset and ties it to the caller, thread and operation. (2) Client uploads one JPEG, max 5 MiB. (3) Publish/join callable validates ownership, object generation, nonzero size, actual JPEG decodability and reasonable dimensions. Bind validation to the immutable object. (4) In a Firestore transaction, first recognize an exact replay; otherwise recheck eligibility and server time, then write contribution, count, membership index, committed asset and result together. Publish also creates the thread and daily guard. Join claims peopleCount + 1 and sets full when that becomes 9. A second concurrent call cannot claim the same slot. Reusing a request key with different input fails. Backend derives identities and timestamps; clients cannot send authoritative values.

**Expiry:** use expiresAt as the authority on every join and chat write, including retries following transaction contention. A periodic backend job materializes archived status idempotently. Reads show the journal as soon as expired even when the job is late. Remove stale cards locally and recheck on opening them. For a demo use emulator fixtures with a near deadline or already-expired clock, keeping the production interval at 12 hours.

**Photos and failures:** failed uploads or rejected joins never consume slots. Transactionally claim stale pending assets as deleting before cleanup; never delete a committed object. Use authenticated reads, avoid generating or sharing bearer download URLs, and verify token/metadata handling in the chosen upload path. Store private conversation only in messages. All writes except authorized file creation run inside authenticated backend code. Admin SDK bypasses client rules; enforce these checks inside callables too. See [Firestore rules](firestore.rules) and [Storage rules](storage.rules). Storage-to-Firestore rule lookups require the services to be connected in the development project.

**Query plan:** Home queries open threads whose expiresAt is in the future; check required composite index for status + expiresAt. My Threads reads the caller’s index. Detail loads contributions by slot; members listen to messages by sentAt. Unsubscribe and clear user-specific views on sign-out.

## Acceptance

| Test | Required result |
|---|---|
| A publishes; B joins from a second client | Count moves 1/9 → 2/9; A and B can exchange a text; restarting both clients restores photos, membership and chat. |
| Race at 8/9 | Seed creator + seven responders; two new UIDs submit simultaneously. Exactly one acceptance, nine total records, no tenth slot. Full leaves discovery; members can still chat. |
| Deadline, full and partial fixtures | At server time >= deadline, joining and sending messages fail even if the archive job has not run. Both threads open as journals at their original IDs; earlier messages remain readable to members. |
| Personalized journal | A and B see exactly the same unique assets with their respective photos centered. C sees public photos, cannot read or write chat even via a direct SDK request. |
| Storage authorization | Unauthenticated reads, foreign pending reads/uploads, oversize files, unsupported types, and committed file replacement/deletion fail. A JPEG declared by MIME alone but failing decoding never becomes committed. |
| Retry and interruption | Exact replay after lost acknowledgement returns original IDs. Repeated tap, failed upload, daily-limit rejection or last-slot loss never creates extra membership or exposes pending photos. |
| Publication permanence | After server acceptance all clients, including the author, are denied photo edits/deletes. Before acceptance the draft can be retaken. |

**Local reference:** run `python3 prototype/round1/check_model.py` from the repository root. [model.sql](model.sql) models the core constraints in SQLite to illustrate keys and relationships. The app uses one Firebase backend. The local check covers database constraints; it does not exercise Firebase authorization, real concurrency, networking, or the iOS UI.

**Deliver to frontend:** runnable Swift test target, callable implementations, dev/emulator setup and fixture instructions, rules and indexes, acceptance results plus a short two-client recording. Deploy to a development project only after local emulator checks.
