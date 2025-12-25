# Native Documents Feature - Replace Google Drive Dependency

## Problem Statement

- Current document storage relies on Google Drive integration
- Requires users to have/authorize Google accounts
- One community member is hesitant to use Google
- Documents are hard to find/navigate for some users

## Current Document Usage

Based on community feedback, documents fall into these categories:

1. **Meeting agendas** - Topics for upcoming meetings
2. **Decision logs** - Record of community decisions (already exists in Conduit)
3. **Collaborative documents** - Living docs that evolve (agenda items, proposals)
4. **Reference documents** - Static docs (bylaws, handbook, policies, etc.)

## Proposed Native Features

### 1. Agenda Items / Meeting Prep

- Simple list where people add topics for next meeting
- Async discussion on each item before the meeting
- Mark items as "discussed" or "tabled"
- Link to decisions made from agenda items
- Could tie into existing Decisions feature

### 2. Meeting Minutes

- Markdown document created per meeting
- Template with date, attendees, agenda items discussed
- Link to decisions made
- Searchable archive of past meetings

### 3. Reference Documents

- File uploads via ActiveStorage (PDFs, images, etc.)
- Simple categorization/tagging
- "Pinned" or "Quick Links" section for frequently-used docs
- Search functionality

### 4. Wiki / Pages (Optional)

- Simple markdown-based pages for living documents
- Version history
- Good for things like community handbook, policies, procedures

## Benefits of Going Native

- No Google account required for anyone
- Everything searchable in one place
- Tighter integration (link decisions to agenda items, meetings, etc.)
- Full control over UX
- Simpler onboarding for new members

## What We'd Lose

- Real-time collaborative editing (multiple cursors)
- Google Docs' rich formatting and commenting
- Existing Google Drive folder structure/history

## Trade-off Assessment

For meeting agendas and decision logs, real-time collaboration isn't critical. A simple form for agenda items + markdown editor for minutes would likely work better for actual community workflow.

## Migration Path

1. Build agenda items feature (ties into existing Decisions)
2. Add simple file uploads for reference docs
3. Pilot with community for a few meetings
4. If working well, consider deprecating Google Drive integration
5. Optionally add wiki/pages feature for more complex docs

## Open Questions

- How much formatting do meeting minutes need? (Markdown probably sufficient)
- Should agenda items have voting/reactions?
- Do we need version history on documents?
- How to handle the transition period with existing Google Drive docs?
