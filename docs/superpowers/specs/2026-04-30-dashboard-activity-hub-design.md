# Dashboard Redesign: Activity Hub

## Problem

The desktop dashboard's "Community Wall" (posts feed) is defunct — chat has replaced it. The remaining content (events + documents) feels sparse. The dashboard needs a new purpose.

## Solution

Replace the dashboard with an **Activity Hub** — a unified timeline of upcoming events and meals, with a sidebar for tasks and documents. The hub answers: "What's happening in my community?"

## Desktop Layout

Two-column layout:

### Main Column — "What's Coming Up"

Unified timeline combining Google Calendar events and meals from the database.

- **Data**: Next 10 items by start time, combining calendar events + upcoming meals
- **Grouping**: Items grouped by day with date headers (e.g., "Today — Wed, Apr 30", "Tomorrow — Thu, May 1", "Sat, May 3")
- **Regular events**: Indigo left-border accent, title, time, location
- **Meals**: Amber left-border accent, meal emoji + badge, cook names, attendee count, inline RSVP button
  - RSVP button shows current user's status: "RSVP" (not yet) or "RSVP'd" (confirmed)
  - Meals needing a cook volunteer show a warning: "Needs a cook!"
- **Footer**: "View full calendar" link to `/calendar`
- **Header**: Calendar subscribe button (existing)

### Right Sidebar

Two sections, both lazy-loaded via Turbo Frames:

**My Tasks**
- User's active tasks as a checkbox list (completable inline)
- Limited to ~5 items
- "View all" link to `/tasks`

**Documents**
- 3-5 most recently updated Google Drive files
- File name + last modified timestamp
- "View all" link to `/documents`

## Mobile Layout

Single column, stacked vertically (same content, responsive):

1. Timeline (What's Coming Up)
2. My Tasks
3. Documents

Key change: tasks section now visible on mobile (currently hidden).

## Data Sources

| Section | Source | Method |
|---------|--------|--------|
| Calendar events | Google Calendar API | `GoogleCalendarApiService#get_events` via service account |
| Meals | `Meal` model | Query upcoming meals with cook/RSVP associations |
| Tasks | `Task` model | Current user's active tasks |
| Documents | Google Drive API | `GoogleDriveBrowseService#recent_files` (existing lazy-load) |

### Timeline Merging

Events and meals are fetched separately, then merged into a single list sorted by start time. The controller builds a combined collection, and the view groups by date using Rails `group_by`. Each item is tagged with its type (`:event` or `:meal`) so the view can render the appropriate card style.

## What Gets Removed

- Community Wall / posts section from dashboard view
- `@posts` and `@post` instance variables from `DashboardController#index`
- Separate mobile (`hotwire_native_app?`) and desktop template branches in `index.html.erb` — replaced with a single responsive layout
- Posts controller and model remain in codebase (accessible elsewhere if needed)

## What Stays the Same

- Navigation bar — unchanged
- Documents lazy-loading via Turbo Frames
- Restricted user handling
- Route: dashboard remains at root path `/`

## View Structure

```
dashboard/index.html.erb
  - Timeline section (inline)
    - Day group headers
    - Event cards (partial: _event_card)
    - Meal cards (partial: _meal_card)
  - Turbo Frame: dashboard-tasks
    -> dashboard/_tasks_section.html.erb
  - Turbo Frame: dashboard-documents
    -> dashboard/_documents_section.html.erb (existing, minor updates)
```

## Testing

- Controller test: dashboard index returns merged timeline data
- Controller test: timeline contains both events and meals sorted by date
- Controller test: meal cards include RSVP status for current user
- Controller test: tasks section returns current user's active tasks
- Controller test: restricted users see appropriate content
- System test: RSVP button updates meal status inline
- System test: task checkbox completes task inline
- System test: "View all" links navigate correctly (turbo-frame _top)
