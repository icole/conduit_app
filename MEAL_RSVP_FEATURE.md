# Meal RSVP Feature

A community meal scheduling and RSVP system for the cohousing app.

## Overview

This feature enables:
- **Recurring weekly meals** auto-generated from schedules
- **Open cook signup** (head cook + helpers)
- **Attendee RSVPs** with guest counts
- **Configurable RSVP deadlines** per meal
- **Multi-channel notifications** (email, push, in-app)

## What Was Created

### 1. Context Added
- Updated `.claude-on-rails/context.md` with cohousing community context explaining shared meals, common house, and collaborative living

### 2. Database (5 migrations)

| Table | Purpose |
|-------|---------|
| `meal_schedules` | Recurring meal schedule templates (day, time, location, deadline) |
| `meals` | Individual meal instances generated from schedules |
| `meal_cooks` | Cook volunteer assignments (head_cook/helper roles) |
| `meal_rsvps` | User RSVPs with guest counts and dietary notes |
| `in_app_notifications` | Notification center for all app notifications |

### 3. Models (6 files)

- `app/models/meal_schedule.rb` - Recurring schedule with day_of_week, start_time, rsvp_deadline_hours
- `app/models/meal.rb` - Individual meals with status tracking, cook/RSVP helpers
- `app/models/meal_cook.rb` - Cook assignments with head_cook/helper roles
- `app/models/meal_rsvp.rb` - RSVPs with attending/declined/maybe status and guest counts
- `app/models/push_subscription.rb` - Web push subscription storage
- `app/models/in_app_notification.rb` - In-app notification records
- Updated `app/models/user.rb` with meal associations

### 4. Controllers (4 files)

- `app/controllers/meals_controller.rb` - Full CRUD + cook signup + RSVP actions
- `app/controllers/meal_schedules_controller.rb` - Admin-only schedule management
- `app/controllers/notifications_controller.rb` - Notification center
- `app/controllers/push_subscriptions_controller.rb` - Web push registration

### 5. Views (~20 files)

**Meals:**
- `app/views/meals/index.html.erb` - List with tabs (Upcoming, Needs Cooks, Past)
- `app/views/meals/show.html.erb` - Detail page with RSVP form and cook signup
- `app/views/meals/calendar.html.erb` - Weekly calendar view
- `app/views/meals/my_meals.html.erb` - Personal dashboard (cooking/attending)
- `app/views/meals/new.html.erb` / `edit.html.erb` - Admin meal creation
- `app/views/meals/_meal_card.html.erb` - Card partial for listings
- `app/views/meals/_cook_signup.html.erb` - Cook volunteer section
- `app/views/meals/_rsvp_form.html.erb` - RSVP form with guest count
- `app/views/meals/_attendee_list.html.erb` - Sidebar showing who's coming
- `app/views/meals/_form.html.erb` - Shared form partial

**Meal Schedules:**
- `app/views/meal_schedules/index.html.erb` - Admin schedule list
- `app/views/meal_schedules/new.html.erb` / `edit.html.erb`
- `app/views/meal_schedules/_form.html.erb`

**Notifications:**
- `app/views/notifications/index.html.erb` - Notification center
- `app/views/notifications/_notification.html.erb` - Notification partial

### 6. Background Jobs (4 files)

| Job | Schedule | Purpose |
|-----|----------|---------|
| `GenerateWeeklyMealsJob` | Sunday 6am | Creates meals 4 weeks ahead from active schedules |
| `MealReminderJob` | Daily 9am | Reminds users about meals in next 24 hours |
| `RsvpDeadlineReminderJob` | Every hour :30 | Warns users when RSVPs close in 2 hours |
| `CloseRsvpsJob` | Every 15 min | Closes RSVPs at deadline, notifies cooks |

### 7. Services (2 files)

- `app/services/push_notification_service.rb` - Web push via VAPID/Webpush gem
- `app/services/meal_notification_service.rb` - Orchestrates notifications across all channels (in-app, push, email)

### 8. Mailer

- `app/mailers/meal_mailer.rb` - Email notifications
- `app/views/meal_mailer/notification_email.html.erb` / `.text.erb`

### 9. Configuration

- Added `webpush` gem to Gemfile
- Updated `config/recurring.yml` with job schedules
- Added "Meals" link to navbar (`app/views/layouts/_navbar.html.erb`)

## Routes

```ruby
resources :meals do
  member do
    post :volunteer_cook
    delete :withdraw_cook
    post :rsvp
    delete :cancel_rsvp
    post :close_rsvps        # Admin
    post :complete           # Admin
    post :cancel             # Admin
  end
  collection do
    get :calendar
    get :my_meals
  end
end

resources :meal_schedules, except: [:show] do
  member do
    post :toggle_active
    post :generate_meals
  end
end

resources :notifications, only: [:index] do
  collection { post :mark_all_read }
  member { post :mark_read }
end

resources :push_subscriptions, only: [:create, :destroy]
```

## Getting Started

### 1. Create Meal Schedules (Admin)
Navigate to `/meal_schedules` and create recurring schedules:
- Name: "Tuesday Dinner"
- Day: Tuesday
- Time: 6:00 PM
- Location: Common House Kitchen
- RSVP Deadline: 24 hours before

### 2. Generate Meals
Click "Generate" on a schedule to create meals for the next 4 weeks.

### 3. Users Can:
- View upcoming meals at `/meals`
- Volunteer to cook (head cook or helper)
- RSVP to attend with optional guest count
- View their cooking/attending schedule at `/meals/my_meals`

## Environment Variables

For push notifications to work, set these environment variables:

```bash
VAPID_PUBLIC_KEY=your_public_key
VAPID_PRIVATE_KEY=your_private_key
VAPID_CONTACT_EMAIL=admin@example.com
```

Generate VAPID keys with:
```ruby
require 'webpush'
Webpush.generate_key
```

## Notification Flow

1. **Meal Reminder** (24h before) - All users who haven't RSVPed
2. **RSVP Deadline Reminder** (2h before close) - Users without RSVP
3. **Cook Assigned** - Confirms volunteer + notifies other cooks
4. **RSVPs Closed** - All cooks receive final headcount

All notifications are sent via:
- In-app notification (visible in notification center)
- Web push notification (if subscribed)
- Email notification

## Key Files Reference

| Category | Key Files |
|----------|-----------|
| Models | `app/models/meal.rb`, `app/models/meal_schedule.rb` |
| Controllers | `app/controllers/meals_controller.rb` |
| Views | `app/views/meals/index.html.erb`, `app/views/meals/show.html.erb` |
| Jobs | `app/jobs/generate_weekly_meals_job.rb`, `app/jobs/close_rsvps_job.rb` |
| Services | `app/services/meal_notification_service.rb` |
