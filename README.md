# Curio

[Start here to build the four-screen prototype](prototype/round1/START_HERE.md) · [View the four screens](prototype/round1/ui/Four_Screens.jpg)

**Round-one test override.** Use a 10-minute deadline, at least ten accounts, public delivery to all other testers and private access through following or a valid invitation link. Each thread still has nine places including its creator. The normal duration is 12 hours. [Test configuration](prototype/round1/README.md#test-configuration-and-distribution)

An iOS app concept for noticing everyday discoveries through photo invitations, individual photo letters and a shared journal. Swift and SwiftUI are the intended implementation tools.

## Proposal

- [English — original concept proposal](docs/English/Match_Me_Concept_Proposal_EN.docx)
- [Chinese / 中文 — 原始概念提案](docs/Chinese/Match_Me_Concept_Proposal_ZH.docx)

The original documents retain the previous working name Match Me. The current name is **Curio**.

## Planned features

These are proposed features, not completed functionality. The first test focuses on one invitation → reply → journal exchange. Curio is the selected project. See the [current thread and journal rules](docs/design/Curio_Design_One_Pagers.md).

| Feature | What it does | Scope |
|---|---|---|
| Daily photo invitation | Create one invitation per day with a starting photo and a short question. | MVP; included in first flow test |
| Audience selection | Public photo threads; following affects suggestions. Group chat is limited to the creator and contributors. | MVP interface; delivery approach to confirm |
| Invitation detail | Show the question, creator, open/closed state and remaining reply spaces. | MVP; included in first flow test |
| Photo reply | Submit a photo with an optional short caption; whether captions are required remains an open decision. | MVP; included in first flow test |
| Reply capacity and closure | Count the creator plus up to eight others. At nine photos stop joins and suggestions; at 12 hours archive the thread and stop chat writes. | MVP |
| Incoming photo letters | Open individual responses and distinguish new from read letters. Live delivery requires a working backend; sample delivery may be used for testing. | MVP; included in first flow test |
| Shared journal | Show the prompt above a 3×3 cover, center the viewer’s own contribution, and link to contributors and the retained member-only chat. Published photos are immutable. | MVP; included in first flow test |
| Personal history | Find entries separately as created or joined. | MVP |
| Clear feedback states | Handle empty entries, full/closed invitations, unavailable photos and failed submissions. | MVP |
| Real multi-user exchange | Synchronize photos, replies, capacity and access across devices. | Technical feasibility decision; not yet implemented |
| Large-scale stranger distribution | Distribute invitations to strangers beyond a small test group. | Future extension |

## Plan and feasibility test

[Curio's four-week plan](docs/plans/Four_Week_Plan.md) is written in English, with all checkpoints before Friday class.

Before **Friday, November 20, 2026**, build and test a small Curio feasibility prototype in parallel with a separate Exercising Companion prototype. On November 20, compare findings with classmates and the professor and choose one project. Full implementation continues only for the selected project; the other is paused. If Curio is selected, a usable MVP is due before November 27, followed by two weeks of testing and refinement, with completion around December 20.

## First prototype

[Four-view workflow, Firebase storage contract, SQL reference and acceptance tests](prototype/round1/README.md)

## Backend assignment

[Firebase backend feasibility brief and acceptance tests](docs/backend/Firebase_Backend_Test_Brief.md) — proposed data model, callable APIs, permissions and a real multi-user exchange test; temporary business rules are explicit, with frontend and final rule design deferred.

## AI dialogue

[Curio dialogue record](docs/ai-dialogue/Curio_AI_Dialogue.md) preserves original user wording and summarizes assistant responses, including naming and the visual prototype request.

## Current status

Concept documentation is available. A static visual mockup was generated in chat; no runnable iOS app has been added yet.

Exercising Companion is a separate project with its own [repository, proposal and plan](https://github.com/Joyful-coder-x/exercise_companion_2026_swift_moblie).
