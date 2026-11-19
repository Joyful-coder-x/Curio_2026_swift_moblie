# Curio project working notes

## Project decision — November 19, 2026

The user has stopped pursuing the desktop-pet / Exercising Companion app. Focus development on the photo-invitation and shared-journal project in this repository. Its previously confirmed name is Curio; the user also refers to it as Quro. Do not rename the project or repository solely because of a transcription variation. Preserve the user's wording in dialogue quotations.

Do not resume Exercising Companion development unless the user explicitly requests it. Retain its existing repository and history.

## Required AI dialogue workflow

Starting with the November 19, 2026 instruction, record every subsequent user instruction in `docs/ai-dialogue/Curio_AI_Dialogue.md` as part of handling that instruction.

1. Append the user's original instruction verbatim, preserving language, spelling and punctuation. Do not silently correct names or transcription errors. Clearly label any excerpt if the complete message is unavailable; never invent missing text.
2. If the instruction is in Chinese, add a brief English summary of the user's request, approximately one sentence. Apply this to mixed-language instructions whose main language is Chinese as well.
3. Add a brief English summary of the assistant's response/actions, approximately one sentence. Describe actual results and distinguish proposals, attempted actions and verified completion.
4. Keep entries chronological and dated using the user's timezone, America/New_York, when dates are known. Do not duplicate already recorded instructions.
5. Update the dialogue during the same task, and commit/push repository changes within the user's established authorization. If saving or pushing fails, report it accurately rather than claiming the instruction was recorded remotely.

Use this compact format:

### YYYY-MM-DD — Short topic

**User instruction (verbatim)**
> Original text.

**User request summary (English):** One sentence, required for Chinese instructions.

**Assistant response summary (English):** One sentence describing the response and outcome.

This note records the user's explicit ongoing preference; it does not authorize inventing conversation history or recording credentials/secrets in a public repository.
