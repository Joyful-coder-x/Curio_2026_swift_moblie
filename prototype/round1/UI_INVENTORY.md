# Curio · UI inventory

[Current combined preview](ui/Unified_UI.jpg) · [Run the browser prototype](START_HERE.md#try-the-reference-in-five-minutes) · [Test rules and Firebase contract](README.md)

[Updated mobile Discover preview](ui/Discover.jpg) · The current demo adds 24 public community samples, author bylines and a fixed bottom navigation bar.

## Shared presentation

Use a warm gray paper surface (#F3F0E9), warm white prints (#FFFCF5), brown ink (#49392F) and plum (#59434D). Serif italic captions sit in the lower margin of each print. Use system sans for actions, names, timestamps and counts. The visual unit is one thread: one frame around a square collage and its prompt. Keep metadata outside the frame. On Inbox rows shrink the print, moving the prompt beside it for legibility. Inside the timeline a posted image represents one actual contribution.

For active threads use one image at 1, a 2×2 grid at 2–4 and a 3×3 grid at 5–9. Use stable photo-derived solid colors for missing cells, accepted photos in order, and a count of actual contributors. The current browser implementation has fixture colors and a single pixel sample for uploads; dominant-palette extraction remains a design target. At archive use a fixed 3×3 with the viewer's contribution centered (opener for visitors), other photos in acceptance order and unused slots empty.

## Navigation and page decisions

| Surface | Agreed behavior | Remaining design |
|---|---|---|
| Home / Discover | Two cards per row; visible, active invitations; author, count and time outside each print. Open the thread on tap. Switch between Random and Following creator feeds. | Ranking beyond the test group and production randomization. |
| Inbox | One compact row per thread, photo cover, prompt, latest accessible update and time. Most recent activity first. Browser currently includes delivered invitations with a generic preview. | Decide whether pending invitations share the conversation list or have their own section; decide unread behavior. |
| Active thread, member | Automatic photo-join entry with author and image; chronological messages; own bubbles on right, others on left. Full threads retain member chat until expiry. A newly accepted contributor can read the retained conversation from before their join time. | Member timeline is designed. Visitor entry, full-state wording and composer placement still need review. |
| Mine | Profile header; All / Created / Joined; Active ordered by deadline and Saved journals by latest archive. Same shared print style. Include a Following row that opens the viewer's followed-person list. | Follow/unfollow controls, personal settings entry and profile editing. |
| Create / reply | Camera or library → square crop/review → retake or confirm. Creation adds prompt and Public/Private; a reply uses the existing prompt. Explain permanence before submission. | Final camera, crop, confirmation, progress, permission-denied and failed-submit layouts. |
| Journal | Original prompt, fixed personalized 3×3, contributors, optional follow, member-only read-only conversation and share. Same stable thread ID. | Final journal spread, contributor treatment, and transitions to history/share. |
| Sharing / invitation | Signed-in viewers can redeem a private link. Profile links for following were discussed separately. | Design share sheet, recipient landing, invalid link and signed-out return flow; QR optional. |
| Profile / people / settings | One-way follow, control followers, profile invitation. Mine is the owner's collection. | Other-person profile, follower list, block/unblock and settings have no agreed layouts. |
| Account entry | A top-right settings gear provides stable A–J scenario accounts. The native fixture labels their intended checks: create, saved journal, join/retained history, member chat, near deadline, full thread, empty Inbox/visitor, private follower, ninth-slot race and invite-link access. | Production sign-in, onboarding and recovery have no agreed screens; scenario labels are test-only. |

## Cross-screen behavior

One publication per person per UTC day in the test. One immutable photo per contributor, nine total including the creator. At nine remove from Discover and close joining. At ten minutes archive even a partial group; normal duration is twelve hours. Public reaches every other registered tester; private delivers to current followers and supports authenticated link redemption. Reading a thread does not grant group membership; only an accepted photo does. Preserve local drafts on rejection. Replay, concurrent submissions, offline recovery and permission enforcement belong to the backend acceptance plan.

For the native simulator fixture, active print frames darken from Paper toward Action as the ten-minute deadline approaches; saved journals remain Action purple. Scenario account labels are test-only navigation aids and do not change the production identity model.

Prioritize visitor detail, the create/join form and Journal for the next visual pass. Empty, loading, unavailable, no-permission and retry are states of existing screens. The account and people-management screens can wait for a later round.
