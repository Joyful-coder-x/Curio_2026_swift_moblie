# Curio · Four design sheets for review

Working draft, November 19, 2026. **Decided** reflects the creator's current direction. **Proposed** is a working assumption for review. **Open** requires a product decision. Earlier backend briefs describe previous prototypes, including a follower-only audience and closure on the last reply. Check these sheets before reusing those assumptions.

## 1. Thread lifecycle

| State | Entry | Behaviour | Exit |
|---|---|---|---|
| Draft | Creator takes a photo and writes a prompt | Review, retake or cancel before publishing. Proposed: keep the draft locally. | Successful publication starts the clock. |
| Open | Published, under capacity, before deadline | An accepted photo joins its author to the group. Open threads are eligible for discovery. Members can chat. | Capacity reached → Full. Deadline reached → Saved, even below capacity. |
| Full | Capacity reached before deadline | No new joins or suggestions. Thread remains accessible by link. Existing members can chat. | At 12 hours from publication → Saved. |
| Saved | 12 hours from publication | Creator and contributors keep the journal. The thread remains shareable. | Terminal state for posting. |

**Decided:** 12-hour lifetime for now, capacity of 12 photos, and chat remains active after filling until expiry. **Proposed:** count 12 reply photos plus a separate opening photo, one reply per non-creator, and use server acceptance time for the final slot and deadline. If acceptance fails, preserve the local draft. **Open:** confirm counting and deadline rules, whether the creator can close early, and what the saved journal looks like with zero replies.

## 2. Roles and permissions

Working matrix for an open thread under the latest public-discovery direction. Visitors are signed-in Curio users in this draft. Following is immediate and one-way.

| Action | Visitor | Follower | Creator | Accepted contributor |
|---|---|---|---|---|
| Find public invitation by profile, search or link | Yes | Yes | Yes | Yes |
| Receive suggestions | Eligible in Discover | Eligible in Discover and My Circle | Own thread in My Threads | Joined thread in My Threads |
| Submit a first reply | While open | While open | No, proposed | One per person, proposed |
| Read and write group chat before expiry | No | No by following alone | Yes | Yes |
| Receive completed journal in My Threads | No | No by following alone | Yes | Yes |
| Open a shared journal link | Shareable; public contents to confirm | Same | Yes | Yes |

**Decided:** preventing someone from following must still allow them to find public content by search or link. Following and unfollowing do not change public visibility. **Open:** whether to retain any strictly private mode; whether every accepted reply and caption is visible to nonmembers before and after expiry; whether preventing following also stops new joins or communication in shared groups. Also decide whether a link works when signed out. **Proposed:** public photos/captions with a disclosure before sending, member-only chat, and a separate control if interaction blocking is needed.

## 3. Data relationships and ownership

Proposed Firebase model. Decide the meanings below before fixing collection names or indexes.

| Record | Relationship / storage | What it enables |
|---|---|---|
| User and follow restriction | Auth UID; Firestore profile, directed follow edge and separate prevent-follow edge | Following, profile discovery and suppression of recommendations without changing public read access |
| Thread | One creator; prompt, opening photo reference, server publish/expiry times, capacity and accepted count | Open, Full and Saved states plus a stable share link |
| Photo contribution | One thread and author; private upload first, accepted asset path and optional caption in Firestore; JPEG bytes in Storage | Acceptance creates membership and a place in the journal |
| Membership and message | User × thread with role and read position; messages scoped to thread | Inbox thread list, unread updates, access to chat |
| Journal | One per thread, referencing the opening photo and accepted contributions | Same journal for all members, one canonical link; access to photo bytes follows the chosen visibility policy |

**Proposed invariant:** accepting a contribution records the slot, contribution and membership together in a server transaction. A retry uses the same request ID. Check the deadline at commit even if an archive job is delayed. An upload on its own grants no membership. **Open:** withdrawal of a photo, retained thumbnails, access after leaving, and retention of chat after expiry. These choices affect both stored records and permission rules.

## 4. Page states and transitions

| Destination | Primary action | Result and exception to design |
|---|---|---|
| Explore / My Circle | Find a prompt and open thread detail | Show remaining time and reply spaces. A stale feed card can open a full or saved thread. |
| Create | Camera → confirm or retake → prompt → Send | Publication opens a thread. Preserve input on failure. Audience control depends on the public/private decision. |
| Thread detail / reply | Confirm photo, read sharing disclosure, submit | Show upload progress; on acceptance open the group. On deadline or full response keep the photo and explain why joining failed. |
| Inbox | Choose a joined thread from list/sidebar | Show member arrivals, photos and chat in time order. At capacity retain composer; at expiry replace composer with View journal. |
| My Threads / journal | Revisit a created or joined thread | Open active detail or saved journal; share the canonical link. Design an empty-history and zero-reply state. |
| Profile | Follow immediately, share profile, manage followers | Distinguish profile link from thread link; explain what preventing a follow does to suggestions, viewing and joining. |

**Ready for wireframes:** these destinations and the happy path. **Open:** whether old chat stays readable, who receives alerts for each event, and wording for sharing visibility and follower controls. Those choices affect the final disclosure and action labels.
