# Roles & Time Tracking Design

## Summary

Add a Roles & Time Tracking system within the existing Tasks tab. Provides visibility into community roles, links tasks to roles, tracks time spent (per-task and monthly reconciliation), and supports committees/task forces as a lightweight variant.

## Goals

- **Visibility**: Who holds what role, what does it entail
- **Fairness**: Track and surface time commitments across the community
- **Simplicity**: No new tab — lives within Tasks tab via a subtle entry point
- **Trust**: Self-service management with audit log for accountability

---

## Data Model

### Role

| Field | Type | Notes |
|-------|------|-------|
| title | string | e.g., "Garden Health Maven" |
| duties | text | Official consented-to responsibilities (structured list) |
| description | text | Living guide maintained by current holder (practical tips, contacts, how-tos) |
| group | string | Category: "HOA Officers", "Garden", "Facilities", "Community" |
| term_length_months | integer | 12 for HOA officers, 6 for others |
| vacant | boolean | True when no current holder |
| role_type | enum | `role` or `committee` |
| community_id | bigint | Tenant scoping |

### RoleAssignment

| Field | Type | Notes |
|-------|------|-------|
| role_id | bigint | FK to Role |
| user_id | bigint | Who holds it |
| assignment_type | enum | `holder`, `backup`, `co_holder` |
| starts_at | date | Term start |
| ends_at | date | Term end |
| active | boolean | Current assignment or historical |

### TimeEntry

| Field | Type | Notes |
|-------|------|-------|
| user_id | bigint | Who logged it |
| task_id | bigint | Optional — null for reconciliation entries |
| role_id | bigint | Optional — null for unaffiliated task time |
| hours | decimal | Time spent |
| logged_on | date | What date the work was done |
| entry_type | enum | `task` (per-task) or `reconciliation` (monthly catch-all) |
| note | string | Optional description for reconciliation entries |

### Task (existing, modified)

| New Field | Type | Notes |
|-----------|------|-------|
| role_id | bigint | Optional FK — links task to a role |

### RecurringTaskTemplate

| Field | Type | Notes |
|-------|------|-------|
| role_id | bigint | FK to Role |
| title | string | e.g., "Grounds walk" |
| description | text | What to do |
| frequency | enum | `daily`, `weekly`, `biweekly`, `monthly`, `quarterly` |
| auto_assign_to_holder | boolean | Auto-assign generated tasks to current role holder |

### Audit Log (PaperTrail)

No custom table needed. Add `has_paper_trail` to `Role` and `RoleAssignment` models. PaperTrail is already configured in this project with `whodunnit` tracking via `ApplicationController`. Provides who changed what, when, and before/after diffs out of the box.

---

## Committees vs. Roles

Committees/task forces use the same `Role` model with `role_type: "committee"`:
- Have multiple members (multiple RoleAssignments with type `holder`)
- Have an estimated total hours rather than ongoing monthly tracking
- Have an explicit end date (the project completes)
- Show in a separate "Committees" group in the directory

---

## UX Design

### Entry Point

- **Not** a new segment in the Active|Backlog|Completed toggle
- A subtle icon/link in the Tasks tab header (e.g., a people/org icon) that opens the Roles directory
- Keeps the primary task workflow uncluttered

### Roles Directory View

- Grouped by category (HOA Officers, Garden, Facilities, Community, Committees)
- Each role shows: title, current holder avatar/name, vacant badge if unassigned
- Tap a role to expand/open detail view

### Role Detail View

- Title, group, term dates
- Current holder(s) + backup
- Duties (official list)
- Description/guide (editable by current holder)
- Linked tasks (filterable)
- Time summary (hours this month, this term, by-month chart)
- "Log time" button for reconciliation entries
- Edit button (opens edit form, creates audit log entry)

### Task Integration

- Tasks get an optional "Role" dropdown when creating/editing
- When viewing tasks filtered by role, you see all tasks linked to that role
- Recurring task templates generate tasks automatically, pre-linked to the role and assigned to current holder

### Time Tracking

**Per-task logging:**
- "Log time" action on any task
- Enter hours + date
- If task is linked to a role, time rolls up to role totals

**Monthly reconciliation:**
- Available from role detail view
- "Log additional hours for [month]" — captures time not tied to specific tasks
- Freeform note field for context (e.g., "side conversations, informal maintenance")

**Workload sentiment:**
- Periodic prompt (monthly): "How's your workload feeling?" — Too much / Just right / Too little
- Stored per-user-per-month
- Surfaced in a community-level report for fairness discussions

### Term Lifecycle

- Roles show term expiration date
- 30-day reminder notification when a term is approaching expiration
- When a term ends: role can be reassigned, previous assignment moves to history
- Role history: list of past holders with their term dates

### Audit Log

- Uses existing PaperTrail gem (`has_paper_trail` on Role and RoleAssignment)
- Viewable per-role in the detail view (collapsible section)
- Shows: who changed what, when, before/after values (via PaperTrail versions)

---

## Scope Boundaries

**In scope (v1):**
- Role CRUD with duties, description, groups, terms
- Role assignments (holder, backup, co-holder)
- Committees as a role variant
- Task-to-role linking
- Time entries (per-task + reconciliation)
- Recurring task templates
- Workload sentiment pulse
- Vacant state
- Audit log
- Term expiration reminders
- Roles directory within Tasks tab

**Out of scope:**
- Sociocracy selection process in-app
- Seasonal effort indicators
- Budget/spending tracking per role
- Role nomination or voting
- Handoff notes (captured by the living "description" field instead)

---

## Mobile Considerations

- Roles directory should be a simple scrollable list grouped by category
- Role detail is a full-screen view (push navigation)
- Time logging is a quick modal (hours + date + optional note)
- Monthly reconciliation accessible from role detail and from a notification prompt
- Workload sentiment is a single-tap (3 options) in a bottom sheet

---

## Migration Path

- Seed initial roles from the Crow Woods roles summary document (16 roles)
- Existing tasks remain unchanged; role_id is optional
- No breaking changes to current task workflow
