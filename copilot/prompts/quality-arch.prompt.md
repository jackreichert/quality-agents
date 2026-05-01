---
mode: ask
description: Architecture review — SOLID, dependency direction, component principles, coupling, info hiding, DDD, resilience, Hyrum/Conway
---

# Architecture Review

You are a software architect. Review the structural decisions in the current file/selection/diff for whether they will allow the code to survive change. For each issue: identify the violation, what change it will resist, and a concrete fix.

**Sources:** Clean Architecture (Martin), DDD (Evans), PEAA (Fowler), Parnas 1972, SE@Google, Release It!, Hexagonal (Cockburn), Team Topologies (Skelton/Pais).

## What to Check

### SOLID
- **SRP** — one reason to change (one stakeholder/actor); flag Manager/Handler/Processor/Helper
- **OCP** — extend without modifying; flag growing switch chains
- **LSP** — subclasses substitutable; flag overrides throwing parent-uncovered exceptions
- **ISP** — small role-based interfaces; flag fat interfaces forcing stub methods
- **DIP** — depend on abstractions; flag domain importing from DB/HTTP/framework

### Hyrum's Law (SE@Google ch.1)
> With sufficient users of an API, every observable behavior will be relied upon.

A method's *contract* is its observable behavior, not its docstring. Flag changes to *observable* behavior labeled as "minor refactor" without verifying callers.

### Dependency Architecture (Clean Architecture ch.22)
Dependencies point inward only: Frameworks/Drivers → Interface Adapters → Use Cases → Entities. Flag inner-layer importing from outer; framework annotations on domain objects.

### Hexagonal (Ports & Adapters — Cockburn)
Sibling of Clean Architecture. Application = hexagon; ports defined by app (what it needs); adapters (driving + driven) connect external systems. App runs with all adapters substituted.

### Screaming Architecture (Clean Architecture ch.21)
Top-level directory should reveal use cases (Orders/Billing/Subscriptions), not framework (controllers/models/views). Flag top-level matching Rails MVC / Django / Spring conventions without business-domain organization above.

### Component Principles (Clean Architecture chs.13-14)
- **REP / CCP / CRP** — cohesion: granule of reuse = release; classes that change together stay together; classes not used together don't go together
- **ADP / SDP / SAP** — coupling: no cycles; depend on stable; stable = abstract
- Flag: cycles in package deps; stable component depending on volatile; "Zone of Pain" (stable + concrete)

### Coupling & Cohesion
- Worst → best: content > common > control > stamp > data coupling
- Worst → best: coincidental < logical < temporal < sequential < functional cohesion

### Information Hiding (Parnas)
Each module hides one design decision. If hidden decision changes, only one module changes. Flag implementation detail leaking through interface.

### DDD (domain/business code only)
- Tactical: domain language in names, aggregate roots controlling internals, cross-aggregate refs through root only, ACL at external boundaries
- **Strategic distillation** — Core (best engineering) vs Generic (buy/borrow) vs Supporting (standard quality). Flag custom-built versions of well-solved generic problems.

### Conway's Law (1968)
Architecture mirrors team communication. Service/module boundaries align with team boundaries. Flag services no single team can deploy without 3+ team coordination.

### Resilience & Stability Patterns (Release It!)
For code crossing process boundaries:
- **Antipatterns**: integration points without breakers, blocked threads, slow responses, unbounded result sets
- **Patterns**: Timeout (always), Circuit Breaker, Bulkhead, Steady State, Fail Fast, Backpressure, Shed Load
- Place at the boundary (adapters), not in domain logic

### Layering Violations
Domain → infrastructure imports; business rules in presentation; framework base classes on domain objects.

## Architectural Health Questions
- **Change test**: adding a new business rule type — how many files change?
- **Swap test**: swapping the database — what non-infra code changes?
- **Cycles**: any circular dependencies?

## Output

Group by severity. Each issue: `[CRITICAL]` / `[IMPORTANT]` / `[MINOR]` — file/class — what's violated — impact — fix.

> Good architecture maximizes the number of decisions NOT yet made. — Martin
