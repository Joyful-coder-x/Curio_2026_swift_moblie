# Curio · Thread and journal design

**Round-one test override.** Use a 10-minute deadline, at least ten accounts, public delivery to all other testers and private access through following or a valid invitation link. Each thread still has nine places including its creator. The normal duration is 12 hours. [Test configuration](../../prototype/round1/README.md#test-configuration-and-distribution)

Current product decisions, November 19, 2026. Use these rules for new work. Firebase implementation choices below are recommendations.

## 1. Thread lifecycle

| State | Photos and membership | Discovery and conversation |
|---|---|---|
| Draft | Review the opening photo and prompt. Retake before sending. | Publication starts the 12-hour clock. |
| Open | Publication fills the first slot with the creator's photo. Up to eight other people can each contribute one photo. An accepted photo gives its author membership. | Eligible for suggestions. The creator and accepted contributors can chat. |
| Full | Nine people and nine photos total. Further submissions are closed. | Remove from suggestions; the public thread link still works. Members can chat until the original deadline. |
| Archived | At 12 hours from publication, archive the thread with its accepted photos, even if fewer than nine people participated. | Stop new messages and contributions. Save a shareable journal for the creator and contributors, with read-only access to their conversation. |

Published photos, including the opening photo, cannot be edited or withdrawn by their authors. Tell people this before their final confirmation. Draft retakes remain available.

## 2. Relationships and access

- Following is long-term and controls suggestions. It is one-way and takes effect immediately. Preventing a follow affects that relationship and suggestions. Public threads remain reachable through search or a shared link.
- The creator and accepted contributors are the group. Their ability to speak lasts until the 12-hour deadline. Keep the contributor roster afterward for credit, cover layout and read access to the archived conversation.
- Membership unlocks the thread's retained conversation from the beginning, including messages sent before that person's photo was accepted; it does not start an empty personal history at join time.
- Signed-in Curio users can see the photos and captions. Only the creator and accepted contributors can open the chat, including from a shared journal. Following, unfollowing or viewing a link does not change participation history.
- The journal's Contributors section allows an optional follow action. Participation never automatically creates a follow relationship.

## 3. Data and implementation guidance

Store one thread with a stable ID, creator, prompt, publication time, expiry, total capacity of nine and accepted-person count starting at one. Give the opening photo a contribution record owned by the creator. Enforce one accepted photo per (thread, user) and protect both its record and Storage object against client edits, replacement and deletion.

Use a server transaction to accept a verified upload, claim a remaining slot and register membership together. Reject a repeat contribution; make an exact retry return the original success. Use server time to check the deadline on each join and chat write. The ninth acceptance sets Full; the deadline archives either Open or Full. Finalization should be safe to repeat.

Keep messages under the thread and authorize reads against the contributor roster. Persist one journal referencing the canonical photos; determine tile order when displaying it to a viewer. A profile follow edge and an archived contributor record have independent lifecycles.

## 4. Pages and acceptance examples

- **Explore / compose:** show available places including the creator (e.g. 1/9) and time remaining. State visibility and photo permanence before Send.
- **Inbox:** list threads the viewer started or joined. An accepted contribution adds the group conversation. At 9/9, keep the message composer for members until expiry.
- **My Threads / journal:** show the original prompt at the top, a 3×3 photo cover, contributor names with follow actions, and a link to the retained chat when it exists. Center the viewing contributor's photo, including the creator's when the creator views it.
- **Implementation defaults to review:** for a non-contributor, center the opening photo; for a partial grid, leave unused cells empty. Keep each accepted photo visible exactly once.
- **Acceptance:** publish with A, accept B–H, then have I and J race for the last slot. Exactly one joins. With nine people the thread drops out of suggestions, the group can still chat, and a visitor can view but cannot join. After expiry the same link opens the photo journal; the visitor cannot read the chat. A and B see the same photo IDs, each with their own centered. Repeat with only the creator and one reply: archive on time with two photos.
