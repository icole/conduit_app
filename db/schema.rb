# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_12_16_232420) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_mailbox_inbound_emails", force: :cascade do |t|
    t.integer "status", default: 0, null: false
    t.string "message_id", null: false
    t.string "message_checksum", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "message_checksum"], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "calendar_events", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.datetime "start_time", null: false
    t.datetime "end_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "google_event_id"
    t.string "location"
  end

  create_table "calendar_events_documents", force: :cascade do |t|
    t.bigint "calendar_event_id", null: false
    t.bigint "document_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_event_id", "document_id"], name: "index_calendar_events_documents_uniqueness", unique: true
    t.index ["calendar_event_id"], name: "index_calendar_events_documents_on_calendar_event_id"
    t.index ["document_id"], name: "index_calendar_events_documents_on_document_id"
  end

  create_table "calendar_shares", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "calendar_id"
    t.datetime "shared_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_calendar_shares_on_user_id"
  end

  create_table "chore_assignments", force: :cascade do |t|
    t.bigint "chore_id", null: false
    t.bigint "user_id", null: false
    t.date "start_date"
    t.date "end_date"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_chore_assignments_on_active"
    t.index ["chore_id", "active"], name: "index_chore_assignments_on_chore_id_and_active"
    t.index ["chore_id"], name: "index_chore_assignments_on_chore_id"
    t.index ["user_id"], name: "index_chore_assignments_on_user_id"
  end

  create_table "chore_completions", force: :cascade do |t|
    t.bigint "chore_id", null: false
    t.bigint "completed_by_id", null: false
    t.datetime "completed_at", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chore_id", "completed_at"], name: "index_chore_completions_on_chore_id_and_completed_at"
    t.index ["chore_id"], name: "index_chore_completions_on_chore_id"
    t.index ["completed_at"], name: "index_chore_completions_on_completed_at"
    t.index ["completed_by_id"], name: "index_chore_completions_on_completed_by_id"
  end

  create_table "chores", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "frequency"
    t.jsonb "frequency_details", default: {}
    t.string "status", default: "proposed", null: false
    t.bigint "proposed_by_id", null: false
    t.date "next_due_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["next_due_date"], name: "index_chores_on_next_due_date"
    t.index ["proposed_by_id"], name: "index_chores_on_proposed_by_id"
    t.index ["status"], name: "index_chores_on_status"
  end

  create_table "comments", force: :cascade do |t|
    t.text "content"
    t.bigint "user_id", null: false
    t.bigint "post_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "commentable_type"
    t.bigint "commentable_id"
    t.bigint "parent_id"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable_type_and_commentable_id"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "decisions", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.date "decision_date"
    t.bigint "calendar_event_id"
    t.bigint "document_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_event_id"], name: "index_decisions_on_calendar_event_id"
    t.index ["decision_date"], name: "index_decisions_on_decision_date"
    t.index ["document_id"], name: "index_decisions_on_document_id"
  end

  create_table "discussion_topics", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_activity_at"
    t.index ["user_id"], name: "index_discussion_topics_on_user_id"
  end

  create_table "documents", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "google_drive_url"
    t.string "document_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "drive_shares", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "folder_id", null: false
    t.string "folder_name"
    t.string "permission_id"
    t.string "role", default: "reader"
    t.datetime "shared_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["folder_id", "user_id"], name: "index_drive_shares_on_folder_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_drive_shares_on_user_id"
  end

  create_table "in_app_notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "body"
    t.string "notification_type", null: false
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.string "action_url"
    t.boolean "read", default: false, null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "idx_on_notifiable_type_notifiable_id_ee4fad2ac8"
    t.index ["notification_type"], name: "index_in_app_notifications_on_notification_type"
    t.index ["user_id", "read"], name: "index_in_app_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_in_app_notifications_on_user_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.string "token"
    t.datetime "used_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
    t.index ["user_id"], name: "index_invitations_on_user_id"
  end

  create_table "likes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "likeable_type"
    t.bigint "likeable_id"
    t.index ["likeable_type", "likeable_id"], name: "index_likes_on_likeable_type_and_likeable_id"
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "meal_cooks", force: :cascade do |t|
    t.bigint "meal_id", null: false
    t.bigint "user_id", null: false
    t.string "role", default: "helper", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meal_id", "user_id"], name: "index_meal_cooks_on_meal_id_and_user_id", unique: true
    t.index ["meal_id"], name: "index_meal_cooks_on_meal_id"
    t.index ["role"], name: "index_meal_cooks_on_role"
    t.index ["user_id"], name: "index_meal_cooks_on_user_id"
  end

  create_table "meal_rsvps", force: :cascade do |t|
    t.bigint "meal_id", null: false
    t.bigint "user_id", null: false
    t.string "status", default: "attending", null: false
    t.integer "guests_count", default: 0, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meal_id", "user_id"], name: "index_meal_rsvps_on_meal_id_and_user_id", unique: true
    t.index ["meal_id"], name: "index_meal_rsvps_on_meal_id"
    t.index ["status"], name: "index_meal_rsvps_on_status"
    t.index ["user_id"], name: "index_meal_rsvps_on_user_id"
  end

  create_table "meal_schedules", force: :cascade do |t|
    t.string "name", null: false
    t.integer "day_of_week", null: false
    t.time "start_time", null: false
    t.time "end_time"
    t.string "location"
    t.integer "max_cooks", default: 2
    t.integer "rsvp_deadline_hours", default: 24
    t.boolean "active", default: true, null: false
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_meal_schedules_on_active"
    t.index ["created_by_id"], name: "index_meal_schedules_on_created_by_id"
    t.index ["day_of_week"], name: "index_meal_schedules_on_day_of_week"
  end

  create_table "meals", force: :cascade do |t|
    t.bigint "meal_schedule_id"
    t.string "title", null: false
    t.text "description"
    t.datetime "scheduled_at", null: false
    t.datetime "rsvp_deadline", null: false
    t.string "location"
    t.string "status", default: "upcoming", null: false
    t.integer "max_attendees"
    t.boolean "rsvps_closed", default: false, null: false
    t.text "cook_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "menu"
    t.index ["meal_schedule_id", "scheduled_at"], name: "index_meals_on_meal_schedule_id_and_scheduled_at"
    t.index ["meal_schedule_id"], name: "index_meals_on_meal_schedule_id"
    t.index ["rsvp_deadline"], name: "index_meals_on_rsvp_deadline"
    t.index ["scheduled_at"], name: "index_meals_on_scheduled_at"
    t.index ["status"], name: "index_meals_on_status"
  end

  create_table "posts", force: :cascade do |t|
    t.text "content"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "endpoint", null: false
    t.string "p256dh_key", null: false
    t.string "auth_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "endpoint"], name: "index_push_subscriptions_on_user_id_and_endpoint", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "status"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "assigned_to_user_id"
    t.date "due_date"
    t.integer "priority_order"
    t.index ["assigned_to_user_id"], name: "index_tasks_on_assigned_to_user_id"
    t.index ["due_date"], name: "index_tasks_on_due_date"
    t.index ["priority_order"], name: "index_tasks_on_priority_order"
    t.index ["user_id"], name: "index_tasks_on_user_id"
  end

  create_table "topic_comments", force: :cascade do |t|
    t.text "content"
    t.bigint "user_id", null: false
    t.bigint "discussion_topic_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "parent_id"
    t.index ["discussion_topic_id"], name: "index_topic_comments_on_discussion_topic_id"
    t.index ["parent_id"], name: "index_topic_comments_on_parent_id"
    t.index ["user_id"], name: "index_topic_comments_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest"
    t.string "provider"
    t.string "uid"
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false
    t.bigint "invitation_id"
    t.datetime "last_active_at"
    t.boolean "restricted_access", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_id"], name: "index_users_on_invitation_id"
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "calendar_events_documents", "calendar_events"
  add_foreign_key "calendar_events_documents", "documents"
  add_foreign_key "calendar_shares", "users"
  add_foreign_key "chore_assignments", "chores"
  add_foreign_key "chore_assignments", "users"
  add_foreign_key "chore_completions", "chores"
  add_foreign_key "chore_completions", "users", column: "completed_by_id"
  add_foreign_key "chores", "users", column: "proposed_by_id"
  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users"
  add_foreign_key "decisions", "calendar_events"
  add_foreign_key "decisions", "documents"
  add_foreign_key "discussion_topics", "users"
  add_foreign_key "drive_shares", "users"
  add_foreign_key "in_app_notifications", "users"
  add_foreign_key "invitations", "users"
  add_foreign_key "likes", "users"
  add_foreign_key "meal_cooks", "meals"
  add_foreign_key "meal_cooks", "users"
  add_foreign_key "meal_rsvps", "meals"
  add_foreign_key "meal_rsvps", "users"
  add_foreign_key "meal_schedules", "users", column: "created_by_id"
  add_foreign_key "meals", "meal_schedules"
  add_foreign_key "posts", "users"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "tasks", "users"
  add_foreign_key "tasks", "users", column: "assigned_to_user_id"
  add_foreign_key "topic_comments", "discussion_topics"
  add_foreign_key "topic_comments", "users"
  add_foreign_key "users", "invitations"
end
