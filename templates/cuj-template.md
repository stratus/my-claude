---
name: [Journey Name]
actor: [Who performs this journey — e.g., "end user", "admin", "API consumer"]
status: draft  # draft | active | deprecated
last-verified: YYYY-MM-DD
---

# [Journey Name]

## Preconditions

- [What must be true before this journey starts]
- [Required state, permissions, or setup]

## Steps

1. [First action the actor takes]
2. [Next action or system response]
3. [Continue until journey completes]

## Success Criteria

- [Observable outcome that confirms the journey worked]
- [What the user sees, receives, or can now do]

## Error Paths

| Failure Point | Expected Behavior |
|---------------|-------------------|
| [Step N fails because X] | [What should happen — error message, fallback, retry] |
| [External service unavailable] | [Graceful degradation or clear error] |
