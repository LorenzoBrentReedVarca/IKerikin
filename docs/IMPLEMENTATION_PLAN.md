# IKeriKin Implementation Plan

**Team activity:** Project Timeline, Milestones, and Risk Assessment (Week 2 Progress Presentation)

**Project duration:** 11 weeks — Mon, Jul 13, 2026 to Sun, Sep 27, 2026

**Repository:** [github.com/LorenzoBrentReedVarca/IKeriKin](https://github.com/LorenzoBrentReedVarca/IKeriKin)

## 1. Project Timeline / Gantt Chart

The project is organized into 7 phases across 11 weeks, from initiation to final presentation.

| Phase | Week 1 | Week 2 | Week 3 | Week 4 | Week 5 | Week 6 | Week 7 | Week 8 | Week 9 | Week 10 | Week 11 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| 1. Initiation & Planning | ■ | ■ | | | | | | | | | |
| 2. System Design | | | ■ | ■ | | | | | | | |
| 3. Core Development / Prototype | | | | | ■ | ■ | | | | | |
| 4. Feature Completion & AI Integration | | | | | | | ■ | ■ | | | |
| 5. System Testing & QA | | | | | | | | | ■ | | |
| 6. Deployment & Documentation | | | | | | | | | | ■ | |
| 7. Final Presentation | | | | | | | | | | | ■ |

### Detailed Task Breakdown

**Phase 1 — Initiation & Planning**

| Task / Subtask | Start Date | End Date | Duration |
|---|:-:|:-:|:-:|
| Requirements gathering & problem definition | Jul 13 | Jul 15 | 3 days |
| Target-user & SPED needs research | Jul 13 | Jul 16 | 4 days |
| Revise and finalize project proposal | Jul 16 | Jul 19 | 4 days |
| Set up Flutter project & layered architecture (presentation/domain/data/application/core) | Jul 14 | Jul 17 | 4 days |
| Define system architecture & tech stack (Riverpod, GoRouter, Supabase) | Jul 17 | Jul 19 | 3 days |
| Progress report, screenshots & Week 2 submission | Jul 20 | Jul 26 | 7 days |

**Phase 2 — System Design**

| Task / Subtask | Start Date | End Date | Duration |
|---|:-:|:-:|:-:|
| UI/UX wireframes for the 5 core screens | Jul 27 | Jul 31 | 5 days |
| Design system: Material 3 theme + accessibility spec | Jul 29 | Aug 2 | 5 days |
| Database schema design (users, children, lessons, progress) | Jul 30 | Aug 3 | 5 days |
| API / Edge Function design for AI lesson generation | Aug 3 | Aug 6 | 4 days |
| Navigation architecture (GoRouter + responsive nav shell) | Aug 3 | Aug 6 | 4 days |
| Design review & documentation sign-off | Aug 7 | Aug 9 | 3 days |

**Phase 3 — Core Development / Prototype**

| Task / Subtask | Start Date | End Date | Duration |
|---|:-:|:-:|:-:|
| Implement auth (registration, login, recovery, offline preview) | Aug 10 | Aug 14 | 5 days |
| Implement child profile CRUD & learner-context fields | Aug 10 | Aug 15 | 6 days |
| Build Home screen + responsive navigation shell | Aug 13 | Aug 17 | 5 days |
| Integrate Riverpod state management across screens | Aug 14 | Aug 19 | 6 days |
| Build AI Lesson Generator screen (form & inputs) | Aug 18 | Aug 21 | 4 days |
| Internal prototype demo & review | Aug 22 | Aug 23 | 2 days |

**Phase 4 — Feature Completion & AI Integration**

| Task / Subtask | Start Date | End Date | Duration |
|---|:-:|:-:|:-:|
| Integrate Supabase Edge Function for AI lesson generation | Aug 24 | Aug 28 | 5 days |
| Build stories, flashcards & quizzes | Aug 24 | Aug 29 | 6 days |
| Build memory & matching games | Aug 27 | Aug 31 | 5 days |
| Implement text-to-speech for stories | Aug 31 | Sep 2 | 3 days |
| Implement Progress Dashboard (weekly/monthly/all-time) | Sep 1 | Sep 4 | 4 days |
| Implement XP, coins, streaks & badges | Sep 2 | Sep 5 | 4 days |
| Implement accessibility settings (text size, contrast, reduced motion) | Sep 4 | Sep 6 | 3 days |

**Phase 5 — System Testing & QA**

| Task / Subtask | Start Date | End Date | Duration |
|---|:-:|:-:|:-:|
| Unit tests (domain & data layers) | Sep 7 | Sep 8 | 2 days |
| Widget tests for the 5 core screens | Sep 8 | Sep 10 | 3 days |
| Integration testing (auth + Supabase + Edge Functions) | Sep 9 | Sep 11 | 3 days |
| Accessibility & usability testing | Sep 10 | Sep 12 | 3 days |
| Bug fixing & performance tuning | Sep 11 | Sep 13 | 3 days |

**Phase 6 — Deployment & Documentation**

| Task / Subtask | Start Date | End Date | Duration |
|---|:-:|:-:|:-:|
| Final bug fixes & code cleanup | Sep 14 | Sep 15 | 2 days |
| Build & verify Android/iOS/Web/Desktop releases | Sep 15 | Sep 17 | 3 days |
| Finalize documentation (README, proposal PDF, screenshots) | Sep 16 | Sep 18 | 3 days |
| Deploy web build / prepare release artifacts | Sep 18 | Sep 20 | 3 days |

**Phase 7 — Final Presentation**

| Task / Subtask | Start Date | End Date | Duration |
|---|:-:|:-:|:-:|
| Prepare final presentation slide deck | Sep 21 | Sep 23 | 3 days |
| Prepare live demo script & rehearse | Sep 23 | Sep 25 | 3 days |
| Final presentation & documentation submission | Sep 26 | Sep 27 | 2 days |

## 2. Milestones and Deliverables

| Milestone | Expected Output | Target Date |
|---|---|:-:|
| Project Proposal Approved | Approved Proposal | Week 2 |
| System Design Completed | Design Documents | Week 4 |
| Prototype Finished | Functional Prototype | Week 6 |
| System Testing | Test Report | Week 8 |
| Final System Completed | Completed System | Week 10 |
| Final Presentation | Presentation & Documentation | Week 11 |

## 3. Risk Assessment and Contingency Plan

| Risk | Impact | Contingency Plan |
|---|:-:|---|
| Team member unavailable (illness, exams, personal issues) | Medium | Reassign tasks to other members; keep architecture and progress documented so any member can pick up a layer (presentation/domain/data/application) |
| Delay in AI/Supabase Edge Function integration | High | Build a local/mock lesson generator fallback first; adjust the schedule and prioritize core offline features over AI polish |
| Internet connectivity issues (Supabase requires network access) | Medium | Rely on the existing offline preview mode (SharedPreferences); prepare offline demo copies and a backup mobile hotspot for presentations |
| Hardware failure or device loss | High | Commit and push code to GitHub frequently; store data in Supabase (cloud); keep a secondary test device/emulator available |
| Scope changes / feature creep | High | Lock the core feature list after the design phase; require adviser approval before adding new features; maintain a change-request log |
| Sensitive child data privacy (disability, health & learning information) | High | Store only necessary data, use Supabase Auth and row-level security, follow the Data Privacy Act, and avoid collecting identifiable data beyond what is needed |
| Cross-platform UI inconsistencies (Android/iOS/Web/Desktop) | Medium | Use the shared ResponsiveGrid/ResponsiveBody widgets, test on multiple screen sizes each sprint, and run `flutter analyze`/`flutter test` before every merge |
| AI-generated content inaccurate or inappropriate for a child's needs | High | Add a content-review step and prompt guardrails tailored to each disability/learning profile; fall back to curated templates if AI output fails validation |
