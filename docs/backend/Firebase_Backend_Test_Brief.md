# Curio — Firebase backend feasibility assignment

Date: November 19, 2026. Status: proposed implementation contract, not implemented code or final product rules.

For the current publishing and follow test, use the [publish and follow assignment](Publish_and_Follow_Test_Request.md). Its public and follower-based access rules supersede the private-test allowlist below for open invitations.

## 1. Workstream boundary

The user clarified that product-flow implementation and Firebase belong to the same backend assignment. The other workstream covers detailed product rules, frontend flow and UI, which will be worked through with the user afterward. Do not design finished pages or claim that the temporary rules below are final decisions.

Deliver a backend and a minimal test harness proving one real exchange: A publishes a photo invitation; B submits a photo response; A receives an unread letter; A closes the invitation; both can reopen the same shared journal. A third, unauthorized account C must not gain access. No polished app screens are required for acceptance.

## 2. Rules needed to make the test executable

Confirmed concept requirements: one new invitation per user per day; a starting photo and short question; at most twelve accepted replies, with no minimum; first twelve completed replies win; full invitations close; replies are photo letters; creator and contributors keep the completed entry; created and joined history are distinct; users may participate in multiple invitations.

The following are explicit TEST DEFAULTS requiring later product review:

| Topic | Temporary backend behavior |
|---|---|
| Audience | Private test invitations to an explicit, server-validated list of test UIDs. No public feed, friend graph or random distribution in this assignment. |
| Daily boundary | UTC calendar day, computed on the server at publication. This is a test convention, not the final reset timezone. |
| Repeat reply | One accepted reply per non-creator UID per invitation; creator cannot reply to their own invitation. |
| Photo source | Camera or photo library accepted; no claim that a photo was captured today. |
| Photo layout | Starting photo is separate from the twelve response slots. |
| Visibility while open | Creator sees all accepted replies; each contributor sees only their own reply. Invited non-contributors cannot browse others' replies. |
| Closing before full | Creator may explicitly close any open invitation, including an empty one. No automatic time deadline yet. An unfilled invitation remains open until manually closed. |
| Visibility after closing | Creator and accepted contributors see the journal and its accepted replies. Merely being invited does not grant completed-journal access. |
| Text limits | Question: 1–140 characters after trimming; reply caption: optional, at most 140. Validate on server. |
| Images | JPEG for this test, at most 5 MiB per uploaded object. Backend verifies decodability and dimensions, not just declared MIME type. |
| Reopen/edit/delete | No reopening or editing accepted content in this feasibility test. Document withdrawal/deletion as an unresolved product requirement, not a supported capability. Use consenting test content only. |

State machine: `draft → open → closed`. Publish starts accepting replies. Twelfth committed reply or creator closure ends acceptance. No reverse transitions. Drafts do not consume the daily allowance; successful publication does, even if the creator closes it immediately. Never accept a reply to a draft or closed invitation.

## 3. Firebase components

- SwiftUI test client: use Swift Package Manager products FirebaseAuth, FirebaseFirestore, FirebaseStorage and FirebaseFunctions.
- Firebase Authentication: email/password test accounts A, B and C, provisioned in the development environment. Use stable UIDs; do not share one login between devices. Defer production sign-in UI.
- Cloud Firestore: invitation state, responses, memberships, journal references, inbox/read state and history. Do not store image bytes/base64 here.
- Cloud Storage for Firebase: private image objects. Store object paths/asset IDs in Firestore, not public download-token URLs.
- Cloud Functions for Firebase, TypeScript: callable endpoints for business mutations, validation, capacity, daily limits and closure. Take the UID from authenticated context; never trust a supplied author UID.
- Firestore snapshot listeners: foreground arrival/read-state demonstration. FCM/APNs background push is not required for this test and must not be claimed as implemented.
- Firebase Local Emulator Suite: repeatable Auth, Firestore, Functions and Storage tests; one development-project device test before acceptance.

Use a separate development project, a documented region selection and deny-by-default security rules. Storage currently requires Blaze billing; deployed Functions also require billing setup. Owner configures billing and budget alerts; alerts are not a hard spending cap. Emulator-only work can begin first. Do not create paid infrastructure as part of this documentation task.

## 4. Data model

IDs are server-generated unless a deterministic ID is specified. Timestamps are server-controlled. The client cannot change owner, membership, response count, sequence or state.

| Firestore path | Fields and purpose |
|---|---|
| `users/{uid}` | `displayName`, `createdAt`; own profile only for the test. Do not put passwords here. |
| `invitations/{invitationId}` | `creatorUid`, `prompt`, `audience: private_test`, `memberUids` (creator plus eligible test users), `status`, `openingAssetId`, `responseCount: 0...12`, `capacity: 12`, `participantUids` (accepted responders only), `createdAt`, `publishedAt`, `closedAt`, `closeReason: full|creator|null`, `schemaVersion: 1`. Membership is immutable after publication for this test. |
| `invitations/{id}/responses/{authorUid}` | Deterministic document ID enforces one reply per UID. Fields: `authorUid`, `assetId`, `caption`, `acceptedAt`, `sequence: 1...12`. Exists only for accepted responses. |
| `journals/{invitationId}` | `invitationId`, `creatorUid`, `viewerUids` (creator plus accepted contributors), `closedAt`, `responseCount`, `openingAssetId`. Created exactly once at closure; reference original response documents instead of duplicating photos. |
| `users/{uid}/invitationRefs/{invitationId}` | Backend-created discovery references for creator/invitees: `invitationId`, `createdAt`. These grant no extra access. |
| `users/{uid}/entryRefs/{invitationId}` | `invitationId`, `role: created|joined`, `createdAt`. Created for creator at publication and responder at acceptance. Client checks invitation state to distinguish open exchanges from completed journal entries. |
| `users/{creatorUid}/letters/{invitationId_authorUid}` | Deterministic ID. `invitationId`, `responseId`, `senderUid`, `createdAt`, `readAt: null|timestamp`. Created atomically with acceptance. Client may only set its own readAt; other fields immutable. |
| `users/{uid}/dailyInvitations/{YYYY-MM-DD}` | `invitationId`, `publishedAt`. Server-only guard against a second published invitation that UTC day. |
| `assets/{assetId}` | `ownerUid`, `invitationId`, `kind: opening|reply`, `responseId` if reply, `storagePath`, `state: pending|committed|deleting`, `createdAt`, `expiresAt`, verified size/type/dimensions after validation. Server-controlled upload authorization and read scope. |
| `users/{uid}/operations/{requestId}` | Server-only idempotency record: operation type, input hash, referenced draft/asset or final result. Same key with different input must fail. |

Storage path: `assets/{ownerUid}/{assetId}/photo.jpg`. No client-selected arbitrary paths, overwrites or deletes. Each new attempt uses a server-authorized asset ID. Pending files are readable only by their owner; committed reads follow the associated opening-photo or reply permissions below.

## 5. API contract and upload sequence

All mutations below are authenticated callable functions. Errors include a stable application code, a readable message and retryability; distinguish app codes from Firebase transport errors.

| API | Input | Output and contract |
|---|---|---|
| `prepareInvitation` | `requestId`, `prompt`, `invitedUids` | `{invitationId, assetId, storagePath}`. Validate inputs and test UID allowlist; create an inaccessible draft and pending opening asset. No daily allowance consumed yet. |
| `publishInvitation` | `invitationId` | Verify immutable uploaded object belongs to this draft and is a valid image. Transaction changes draft to open, consumes server UTC daily allowance, commits the asset, and creates creator/invitee refs. Repeated publish of the same already published invitation returns its result without another allowance. |
| `prepareReply` | `requestId`, `invitationId` | `{assetId, storagePath}`. Validate membership and current eligibility, create pending reply asset tied to caller UID. This is not a reserved reply slot; final eligibility must be rechecked at commit. |
| `submitReply` | `invitationId`, `assetId`, `caption` | Verify uploaded immutable image; transaction accepts one response, increments count, creates creator letter and responder entry ref, updates participants, and commits asset. On acceptance 12, close and create journal in the same transaction. Return `{responseId, sequence, invitationStatus}`. |
| `closeInvitation` | `invitationId` | Creator-only transaction: close once, set reason and create canonical journal. Closed again returns existing result. |

Upload steps: call prepare → upload bytes with Firebase Storage SDK to the returned path → wait for successful upload → call publish/submit → show success only after backend confirmation. Do not count a photo upload as an accepted response.

If the function response is lost, retry with the same operation identifiers. For a reply already accepted from the same asset and normalized caption, return the previous result before checking current closed/full state; a different attempted replacement returns ALREADY_REPLIED. Preserve exact results for retry recovery. Never run Storage uploads/copies or other external side effects inside a Firestore transaction callback, which may rerun.

Submission transaction must READ the invitation, existing response, asset, and any other required records before WRITES; verify creator/member eligibility, open state and capacity at commit. Concurrent calls must contend on the invitation document. All business data changes for acceptance or closure are atomic. Race with manual closure has one serialized winner: a reply committed first is included; a reply committed after closure is rejected.

Storage and Firestore are not one cross-service transaction. Upload first, then commit references. Client writes are create-only, preventing replacement during validation. Orphan cleanup is required: an expired pending asset is transactionally marked deleting before removal; submit must reject deleting assets. Delete only files whose asset records were successfully claimed for cleanup, never files referenced by a committed reply. A scheduled or documented development cleanup command is sufficient for the test. Upload failures, full invitations and lost races must not leave ghost responses or consume slots.

Suggested app-level error codes: UNAUTHENTICATED, FORBIDDEN, INVALID_INPUT, DAILY_LIMIT_REACHED, INVITATION_NOT_OPEN, INVITATION_FULL, ALREADY_REPLIED, ASSET_NOT_READY, ASSET_EXPIRED and REQUEST_CONFLICT. In a full race, return a deterministic closed/full error; no silent success. Network/transport failures remain distinct.

## 6. Read permissions and queries

Implement AND TEST both Firestore rules and Storage rules. Admin SDK bypasses Firestore rules, so each callable must independently enforce authentication, authorization and validation.

- Draft: creator only. Open invitation and opening photo: creator and explicit eligible members. Closed invitation/opening photo: creator and accepted contributors only.
- Reply while open: creator or that reply's author. Reply after closure: creator or an accepted contributor. Apply equivalent conditions to the underlying image asset; blocking only Firestore metadata is insufficient.
- Journal: creator and accepted contributors only. C must fail even if given exact document IDs or Storage object paths.
- Direct client writes to invitations, responses, journals, assets, refs and daily guards are denied. Own profile edits are restricted to allowed fields; own letter edits may change only readAt. No broad authenticated-user read/write rule.
- Storage rules: require authorized pending upload intent, matching caller/path, unexpired state, JPEG MIME and size <= 5 MiB, and object not already present. Backend validates actual image content. Pending reads owner-only; committed reads reflect parent and response permissions through Firestore lookups. Enable the required cross-service rules permissions.
- Do not call getDownloadURL and persist/share long-lived bearer-token links as the private-photo access mechanism. Use authenticated SDK reads; local image caches must be user-scoped and cleared on sign-out. Previously downloaded images cannot be retroactively recalled.

Query plan:
1. Discover only own `invitationRefs`, then fetch referenced invitation documents; skip refs whose access has ended. No global collection scan.
2. Creator listens to own `letters` ordered by createdAt and fetches referenced replies. Reading a letter updates only readAt. No unread boolean on a shared response.
3. Creator reads all responses of their invitation. Before closure, a contributor fetches only their deterministic own response; after closure, permitted viewers can read the response collection ordered by sequence.
4. History queries own entryRefs by role, ordered by createdAt; follow the reference to open detail or closed journal. Check in required Firestore indexes.
5. Remove listeners when leaving the view/signing out. Test each exact query against rules: rules are not filters.

Journal UI later renders the original opening photo plus referenced replies. Do not create separate copied photo albums for every participant. No public feed, full-text search or Realtime Database is required.

## 7. Assignment tracks within the backend workstream

Both tasks belong to ONE backend delivery; no frontend styling assignment is included.

- Task A: implement the callable API, Firestore schema, Storage flow, permissions, daily/capacity invariants and repeatable automated tests.
- Task B: provide a minimal Swift test harness or integration script and evidence that two accounts/devices complete the real exchange. A debug form can expose IDs and buttons; it is not the product UI. Supply an adapter callable by the later frontend: prepare/upload/publish, load detail, prepare/upload/submit, listen to letters, mark read, close and load journal.

Use Firebase Emulator Suite for negative/security/concurrency tests and a separate development Firebase project for a small real-device exchange. Setup/config files, rules and functions must be version-controlled. Keep credentials, private service-account keys and real user photos out of the public repository.

## 8. Acceptance test set

Technical pass requires all mandatory cases. Product desirability is evaluated later and must not be inferred from a working backend. Use fresh fixtures between tests; do not weaken the one-per-day rule to reset them in production APIs.

| ID | Tester action | Required evidence / pass condition |
|---|---|---|
| B01 | Authenticate A and B separately; publish A's photo invitation targeting B. | One open invitation, committed readable opening image, A's entry ref and B's invitation ref persist. |
| B02 | B uploads and submits a photo. | One response with B's UID, count 1, sequence 1, one unread letter for A and one joined ref for B. |
| B03 | A observes while online, opens letter, restarts app. | New letter appears without manual refresh; in a documented stable-network test, target <= 5 seconds after commit. readAt persists. This is not a background push claim. |
| B04 | A closes; A and B reopen after restarting. | One journal ID equal to invitation ID, same source photos/captions on both devices, history correctly classified. |
| B05 | C tries exact invitation, response, journal and image paths; B tries others' open replies. | All prohibited metadata and image reads fail, including direct SDK calls bypassing the test UI. |
| B06 | B submits concurrently/retries after a lost response, then tries another asset. | One accepted response/count increment/letter; exact retry returns original result; replacement is rejected. |
| B07 | Seed 11 accepted replies; two different eligible users race for last slot. | Exactly one succeeds; final count and response collection size are 12; exactly one canonical journal; no 13th reply. Use controlled emulator accounts. |
| B08 | Race creator closure with a submission. | Serializable result; no accepted reply missing from final journal and no acceptance after committed closure. |
| B09 | Publish two different invitations as A on same server day; test boundary with controlled server-time fixtures. | Second publication denied; draft/upload alone does not consume allowance; retry first publication succeeds idempotently. |
| B10 | Force upload failure, invalid image, offline submit, oversized file or expired asset. | No successful-response UI acknowledgment, no ghost response/count increase; stable error and safe retry. Do not treat local Firestore cache as server acceptance. |
| B11 | Attempt direct counter/state/membership writes or submit as another UID. | Rules or callable checks reject every attempt. |
| B12 | Close with 0, 1, 3 and 12 replies in separate fixtures. | Correct empty/completed result; all accepted participants retain access, invited nonparticipants do not. Full closes automatically. |
| B13 | Upload without finalization, expire asset, race cleanup vs submission. | Cleanup cannot delete committed assets; a deleting/expired asset cannot be newly accepted. |
| B14 | A logs out and B signs in on the same device. | A-only listeners/cached images are cleared from app presentation; rules reject unauthorized reads. |

Deliver: pull request/source commit; setup instructions; sample configuration; Firestore and Storage rules; index definitions; functions; fixture/reset scripts; automated test results; two-device demo with IDs and Firestore/Storage evidence; known failures and limitations. Screenshots alone do not prove race handling or permissions. Do not declare the assignment complete if only a local mock works.

## 9. Official implementation references

- [Add Firebase to an Apple project](https://firebase.google.com/docs/ios/setup) — SDK setup.
- [Callable Functions](https://firebase.google.com/docs/functions/callable) — authenticated Swift-to-backend calls.
- [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions) — atomic capacity and lifecycle operations.
- [Firestore listeners](https://firebase.google.com/docs/firestore/query-data/listen) — foreground new-letter delivery.
- [Secure queries](https://firebase.google.com/docs/firestore/security/rules-query) — query design must match authorization.
- [Storage security conditions](https://firebase.google.com/docs/storage/security/rules-conditions) — file validation and Firestore-based authorization.
- [Emulator Suite](https://firebase.google.com/docs/emulator-suite/connect_and_prototype) — repeatable backend tests.
- [Storage billing requirements](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024) — Blaze requirement.

The architecture and temporary rules above are project-specific recommendations derived from the concept and official Firebase capabilities, not a claim that Firebase automatically implements Curio's business rules.
