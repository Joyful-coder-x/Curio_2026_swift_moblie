# Developer request · Publish and follow a Curio photo invitation

Curio is an iOS app where someone posts a photo and asks others to respond with one of their own. Please deliver a small SwiftUI test client and Firebase backend for two features: publishing an invitation and using a follower relationship to discover and open it. I need to be able to run both flows with separate accounts before I build the final UI.

## Feature 1 · Capture and publish

1. On **Home**, tap **New invitation**, take a photo with the camera, and show it at review size. Offer **Retake** and **Use photo**. Keep the draft local through review. If camera access is denied, explain how to enable it and allow cancellation.
2. On **Compose**, show the confirmed photo and a one-line text field labeled **What would you like people to send back?** Show these example prompts as suggestions: “Try matching my photo,” “Show me your pet,” and “Show me a picture of where you are.” Require a confirmed photo and a nonblank prompt before enabling **Send**.
3. Offer **Public** and **Private · Followers**. Public exposes a **Notify followers** switch. Private explains that followers will be notified automatically. Apply the rules in the table on the server as well as in the UI.
4. On **Send**, show upload progress, retain the draft if sending fails, and offer retry. After the server confirms publication, return to **Home → Mine**. Show the author’s sent invitations newest first, each with its photo thumbnail, prompt, audience and sent time. Opening a row shows its detail and share action. The list must survive a relaunch.

| Setting | Who can open the published invitation and photo? | Who receives an in-app notification at publication? |
|---|---|---|
| Public, switch off | Any signed-in Curio user | Nobody |
| Public, switch on | Any signed-in Curio user | The author's followers |
| Private | Author and current followers | The author's followers, automatically |

## Feature 2 · Follow and share

On a simple test profile, B can tap **Follow** for author A. Use a one-way relationship. For this prototype, following takes effect immediately, including for existing open private invitations. Unfollowing removes access on the next server read. Only followers at publication receive the notification. These are test assumptions to review with the frontend developer.

Provide **Share invitation** on post detail. Return a reusable link containing an opaque invitation code. For a self-contained test build, register `curio://invite/<code>` and accept the same code in **Home → Open invitation**. The iOS share sheet can copy/send the link. A QR code encoding the same link is optional. Opening via the link or entering the code should resolve to the same detail screen after sign-in. Check current access every time, including photo reads. A forwarded private link must reveal no prompt, thumbnail or photo to an unauthorized viewer. Show **Access unavailable** for that case. Treat follower alerts as persisted inbox entries for this test. Device push delivery can be tested separately if requested.

## Suggested implementation

Reuse the existing invitation and asset IDs from the [Firebase backend brief](Firebase_Backend_Test_Brief.md). The audience table above replaces that brief's explicit-UID allowlist for publishing and viewing open invitations. The earlier brief covers the later reply and journal lifecycle.

| Component | Responsibility |
|---|---|
| Firebase Auth | Give each session a stable UID. Derive the author and follower identities from the authenticated session. |
| Cloud Storage | Keep the JPEG at the authorized asset path. Start upload after the user confirms the image and taps Send. Use authenticated reads and apply the same access policy as the invitation. |
| Firestore | Store `creatorUid`, `prompt`, `openingAssetId`, `audience`, `notifyFollowers`, `status` and server `publishedAt` in `invitations/{id}`. Keep follower edges at `users/{authorUid}/followers/{followerUid}`, code lookups at `shareCodes/{code}`, and a notification reference at `users/{recipientUid}/notifications/{invitationId}`. |
| Callable Functions | Adapt `prepareInvitation` and `publishInvitation` to accept the audience policy. Validate the image, normalize private notifications to on, and reuse a request ID across retries. For the small seeded test group, commit publication, a unique code mapping and one notification per eligible follower together. Retain the daily limit. Add `setFollowing(authorUid, enabled)` and `resolveInvite(code)` with server-side authorization. Restrict code lookup to the server. |
| SwiftUI / Firestore SDK | Read Mine using the author's UID and published status, sorted by server time. Provide separate public and followed-author queries constrained to authorized posts. Add any required indexes. Listen to the current user's notification collection and resolve post access when opened. |

Suggested file boundaries: `ComposeInvitationView.swift` owns camera review, prompt and audience controls. `InvitationService.swift` handles prepare/upload/publish, retries, Mine and link resolution. `FollowService.swift` handles the relationship. `HomeView.swift` exposes Mine, discovery, inbox and code entry. On Firebase, group functions by `invitations`, `follows` and `sharing`, and check in Firestore rules, Storage rules, indexes, seed data and emulator tests. Keep permission checks in the backend even when a SwiftUI control is hidden.

## Acceptance test

Seed three signed-in accounts: A publishes, B follows A, and C starts as a non-follower. Reset fixtures or use separate test dates between publication scenarios so the one-invitation-per-day rule stays active.

| Test | Action | Pass condition |
|---|---|---|
| 1. Capture | A takes photo 1, retakes photo 2, confirms it, and attempts Send with an empty prompt. Then A enters a prompt and sends. | Empty prompt prevents publication. Exactly one sent invitation in Mine contains photo 2 and the entered prompt. Relaunch restores the row. |
| 2. Public, quiet | A publishes Public with notifications off. B and C open it. | Both see the invitation and image. Both inboxes stay empty. |
| 3. Public, notify | Repeat with notifications on. | B gets exactly one alert. C gets none and can still open the public invitation. |
| 4. Private, notify | A publishes Private. B opens the alert. C receives the forwarded share link and also tries the exact photo path. | B sees the correct photo and prompt. C is denied by the backend on both routes. Private publication with the client toggle set to false still notifies B. |
| 5. Relationship change | C follows A and retries the same private code, then unfollows and reopens from a fresh session. | Following grants access to the open private invitation. Unfollowing denies a fresh read of metadata and photo. C receives no retroactive alert. |
| 6. Share and recovery | B opens the link and enters the code manually. A retries after an interrupted send or lost acknowledgement. | Link and code open the same ID. A failed upload leaves Mine and follower inboxes unchanged. Retrying a successful publication returns the same post and code, with no duplicate notification. |

Please deliver one PR with runnable test code, emulator setup and reset instructions, results for all six cases and a short device recording of camera → review → Send → Mine. Include one allowed and one denied private-link read in the results so I can verify the authorization behavior independently of the UI.
