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

ActiveRecord::Schema[8.1].define(version: 2026_09_24_000200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "calendar_shares", force: :cascade do |t|
    t.string "calendar_id"
    t.datetime "created_at", null: false
    t.datetime "shared_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_calendar_shares_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "commentable_id"
    t.string "commentable_type"
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.bigint "deleted_by_id"
    t.datetime "discarded_at"
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable_type_and_commentable_id"
    t.index ["created_by_id"], name: "index_comments_on_created_by_id"
    t.index ["deleted_by_id"], name: "index_comments_on_deleted_by_id"
    t.index ["discarded_at"], name: "index_comments_on_discarded_at"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "communities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "domain", null: false
    t.decimal "monthly_dues_amount", precision: 10, scale: 2
    t.string "name", null: false
    t.jsonb "settings", default: {}
    t.string "slug", null: false
    t.string "status", default: "pending", null: false
    t.string "time_zone", default: "America/New_York"
    t.datetime "updated_at", null: false
    t.index ["domain"], name: "index_communities_on_domain", unique: true
    t.index ["slug"], name: "index_communities_on_slug", unique: true
    t.index ["status"], name: "index_communities_on_status"
  end

  create_table "decisions", force: :cascade do |t|
    t.bigint "community_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.date "decision_date"
    t.bigint "deleted_by_id"
    t.text "description"
    t.datetime "discarded_at"
    t.bigint "document_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["community_id"], name: "index_decisions_on_community_id"
    t.index ["created_by_id"], name: "index_decisions_on_created_by_id"
    t.index ["decision_date"], name: "index_decisions_on_decision_date"
    t.index ["deleted_by_id"], name: "index_decisions_on_deleted_by_id"
    t.index ["discarded_at"], name: "index_decisions_on_discarded_at"
    t.index ["document_id"], name: "index_decisions_on_document_id"
  end

  create_table "document_folders", force: :cascade do |t|
    t.bigint "community_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "google_drive_id"
    t.string "name", null: false
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.index ["community_id", "google_drive_id"], name: "index_document_folders_on_community_id_and_google_drive_id", unique: true, where: "(google_drive_id IS NOT NULL)"
    t.index ["community_id"], name: "index_document_folders_on_community_id"
    t.index ["created_by_id"], name: "index_document_folders_on_created_by_id"
    t.index ["parent_id"], name: "index_document_folders_on_parent_id"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "community_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.bigint "deleted_by_id"
    t.text "description"
    t.datetime "discarded_at"
    t.bigint "document_folder_id"
    t.string "document_type"
    t.string "google_drive_url"
    t.integer "storage_type", default: 0, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["community_id"], name: "index_documents_on_community_id"
    t.index ["created_by_id"], name: "index_documents_on_created_by_id"
    t.index ["deleted_by_id"], name: "index_documents_on_deleted_by_id"
    t.index ["discarded_at"], name: "index_documents_on_discarded_at"
    t.index ["document_folder_id"], name: "index_documents_on_document_folder_id"
  end

  create_table "email_logs", force: :cascade do |t|
    t.bigint "community_id", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "from"
    t.string "mailer_action"
    t.string "mailer_class"
    t.datetime "sent_at"
    t.string "status", default: "pending", null: false
    t.string "subject"
    t.string "to", null: false
    t.datetime "updated_at", null: false
    t.index ["community_id", "created_at"], name: "index_email_logs_on_community_id_and_created_at"
    t.index ["community_id"], name: "index_email_logs_on_community_id"
    t.index ["status"], name: "index_email_logs_on_status"
  end

  create_table "household_dues_payments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "household_id", null: false
    t.integer "month", null: false
    t.boolean "paid", default: false, null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["household_id", "year", "month"], name: "index_household_dues_on_household_year_month", unique: true
    t.index ["household_id"], name: "index_household_dues_payments_on_household_id"
  end

  create_table "households", force: :cascade do |t|
    t.bigint "community_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["community_id", "name"], name: "index_households_on_community_id_and_name", unique: true
    t.index ["community_id"], name: "index_households_on_community_id"
  end

  create_table "in_app_notifications", force: :cascade do |t|
    t.string "action_url"
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "notifiable_id"
    t.string "notifiable_type"
    t.string "notification_type", null: false
    t.boolean "read", default: false, null: false
    t.datetime "read_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "idx_on_notifiable_type_notifiable_id_ee4fad2ac8"
    t.index ["notification_type"], name: "index_in_app_notifications_on_notification_type"
    t.index ["user_id", "read"], name: "index_in_app_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_in_app_notifications_on_user_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "community_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "token"
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.bigint "user_id"
    t.index ["community_id"], name: "index_invitations_on_community_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
    t.index ["user_id"], name: "index_invitations_on_user_id"
  end

  create_table "likes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "likeable_id"
    t.string "likeable_type"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["likeable_type", "likeable_id"], name: "index_likes_on_likeable_type_and_likeable_id"
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "meal_cooks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "guests_count", default: 0, null: false
    t.bigint "meal_id", null: false
    t.text "notes"
    t.string "role", default: "helper", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["meal_id", "user_id"], name: "index_meal_cooks_on_meal_id_and_user_id", unique: true
    t.index ["meal_id"], name: "index_meal_cooks_on_meal_id"
    t.index ["role"], name: "index_meal_cooks_on_role"
    t.index ["user_id"], name: "index_meal_cooks_on_user_id"
  end

  create_table "meal_rsvps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "guests_count", default: 0, null: false
    t.bigint "meal_id", null: false
    t.text "notes"
    t.string "status", default: "attending", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["meal_id", "user_id"], name: "index_meal_rsvps_on_meal_id_and_user_id", unique: true
    t.index ["meal_id"], name: "index_meal_rsvps_on_meal_id"
    t.index ["status"], name: "index_meal_rsvps_on_status"
    t.index ["user_id"], name: "index_meal_rsvps_on_user_id"
  end

  create_table "meal_schedules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "community_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.integer "day_of_week", null: false
    t.time "end_time"
    t.string "location"
    t.integer "max_cooks", default: 2
    t.string "name", null: false
    t.integer "rsvp_deadline_hours", default: 24
    t.time "start_time", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_meal_schedules_on_active"
    t.index ["community_id"], name: "index_meal_schedules_on_community_id"
    t.index ["created_by_id"], name: "index_meal_schedules_on_created_by_id"
    t.index ["day_of_week"], name: "index_meal_schedules_on_day_of_week"
  end

  create_table "meals", force: :cascade do |t|
    t.bigint "community_id", null: false
    t.text "cook_notes"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.bigint "deleted_by_id"
    t.text "description"
    t.datetime "discarded_at"
    t.string "google_event_id"
    t.string "location"
    t.integer "max_attendees"
    t.bigint "meal_schedule_id"
    t.text "menu"
    t.datetime "rsvp_deadline", null: false
    t.boolean "rsvps_closed", default: false, null: false
    t.datetime "scheduled_at", null: false
    t.string "status", default: "upcoming", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["community_id"], name: "index_meals_on_community_id"
    t.index ["created_by_id"], name: "index_meals_on_created_by_id"
    t.index ["deleted_by_id"], name: "index_meals_on_deleted_by_id"
    t.index ["discarded_at"], name: "index_meals_on_discarded_at"
    t.index ["google_event_id"], name: "index_meals_on_google_event_id", unique: true
    t.index ["meal_schedule_id", "scheduled_at"], name: "index_meals_on_meal_schedule_id_and_scheduled_at"
    t.index ["meal_schedule_id"], name: "index_meals_on_meal_schedule_id"
    t.index ["rsvp_deadline"], name: "index_meals_on_rsvp_deadline"
    t.index ["scheduled_at"], name: "index_meals_on_scheduled_at"
    t.index ["status"], name: "index_meals_on_status"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.string "auth_key", null: false
    t.datetime "created_at", null: false
    t.text "endpoint", null: false
    t.string "p256dh_key", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "endpoint"], name: "index_push_subscriptions_on_user_id_and_endpoint", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "recurring_tasks", force: :cascade do |t|
    t.bigint "community_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "default_responsible_user_id"
    t.text "description"
    t.datetime "discarded_at"
    t.integer "estimated_minutes", null: false
    t.string "frequency", default: "weekly", null: false
    t.string "priority"
    t.date "starts_on", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "workstream_id", null: false
    t.index ["community_id"], name: "index_recurring_tasks_on_community_id"
    t.index ["created_by_id"], name: "index_recurring_tasks_on_created_by_id"
    t.index ["default_responsible_user_id"], name: "index_recurring_tasks_on_default_responsible_user_id"
    t.index ["discarded_at"], name: "index_recurring_tasks_on_discarded_at"
    t.index ["workstream_id"], name: "index_recurring_tasks_on_workstream_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.integer "assigned_to_user_id"
    t.bigint "community_id", null: false
    t.datetime "completed_at"
    t.bigint "completed_by_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.bigint "deleted_by_id"
    t.text "description"
    t.datetime "discarded_at"
    t.date "due_date"
    t.integer "estimated_minutes"
    t.date "period_start"
    t.integer "priority_order"
    t.bigint "recurring_task_id"
    t.datetime "released_at"
    t.bigint "released_by_id"
    t.string "status"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workstream_id", null: false
    t.index ["assigned_to_user_id"], name: "index_tasks_on_assigned_to_user_id"
    t.index ["community_id"], name: "index_tasks_on_community_id"
    t.index ["completed_at"], name: "index_tasks_on_completed_at"
    t.index ["completed_by_id"], name: "index_tasks_on_completed_by_id"
    t.index ["created_by_id"], name: "index_tasks_on_created_by_id"
    t.index ["deleted_by_id"], name: "index_tasks_on_deleted_by_id"
    t.index ["discarded_at"], name: "index_tasks_on_discarded_at"
    t.index ["due_date"], name: "index_tasks_on_due_date"
    t.index ["priority_order"], name: "index_tasks_on_priority_order"
    t.index ["recurring_task_id", "period_start"], name: "index_tasks_on_recurring_task_id_and_period_start", unique: true, where: "(recurring_task_id IS NOT NULL)"
    t.index ["recurring_task_id"], name: "index_tasks_on_recurring_task_id"
    t.index ["released_by_id"], name: "index_tasks_on_released_by_id"
    t.index ["user_id"], name: "index_tasks_on_user_id"
    t.index ["workstream_id"], name: "index_tasks_on_workstream_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false
    t.string "avatar_url"
    t.string "calendar_feed_token"
    t.bigint "community_id", null: false
    t.datetime "created_at", null: false
    t.text "dietary_needs"
    t.string "email", null: false
    t.datetime "email_verification_sent_at"
    t.datetime "email_verified_at"
    t.bigint "household_id"
    t.bigint "invitation_id"
    t.datetime "last_active_at"
    t.datetime "last_chat_token_at"
    t.string "name", null: false
    t.string "password_digest"
    t.datetime "password_reset_sent_at"
    t.string "provider"
    t.boolean "restricted_access", default: false, null: false
    t.boolean "super_admin", default: false, null: false
    t.integer "token_version", default: 0, null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["calendar_feed_token"], name: "index_users_on_calendar_feed_token", unique: true
    t.index ["community_id", "email"], name: "index_users_on_community_id_and_email", unique: true
    t.index ["community_id", "provider", "uid"], name: "index_users_on_community_id_and_provider_and_uid", unique: true
    t.index ["community_id"], name: "index_users_on_community_id"
    t.index ["household_id"], name: "index_users_on_household_id"
    t.index ["invitation_id"], name: "index_users_on_invitation_id"
    t.index ["last_chat_token_at"], name: "index_users_on_last_chat_token_at"
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "workstreams", force: :cascade do |t|
    t.bigint "community_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "owner_id"
    t.string "priority", default: "important", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.string "workstream_type", default: "permanent", null: false
    t.index ["community_id", "status"], name: "index_workstreams_on_community_id_and_status"
    t.index ["community_id"], name: "index_workstreams_on_community_id"
    t.index ["owner_id"], name: "index_workstreams_on_owner_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "calendar_shares", "users"
  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "users"
  add_foreign_key "comments", "users", column: "created_by_id"
  add_foreign_key "comments", "users", column: "deleted_by_id"
  add_foreign_key "decisions", "communities"
  add_foreign_key "decisions", "documents"
  add_foreign_key "decisions", "users", column: "created_by_id"
  add_foreign_key "decisions", "users", column: "deleted_by_id"
  add_foreign_key "document_folders", "communities"
  add_foreign_key "document_folders", "document_folders", column: "parent_id"
  add_foreign_key "document_folders", "users", column: "created_by_id"
  add_foreign_key "documents", "communities"
  add_foreign_key "documents", "document_folders"
  add_foreign_key "documents", "users", column: "created_by_id"
  add_foreign_key "documents", "users", column: "deleted_by_id"
  add_foreign_key "email_logs", "communities"
  add_foreign_key "household_dues_payments", "households"
  add_foreign_key "households", "communities"
  add_foreign_key "in_app_notifications", "users"
  add_foreign_key "invitations", "communities"
  add_foreign_key "invitations", "users"
  add_foreign_key "likes", "users"
  add_foreign_key "meal_cooks", "meals"
  add_foreign_key "meal_cooks", "users"
  add_foreign_key "meal_rsvps", "meals"
  add_foreign_key "meal_rsvps", "users"
  add_foreign_key "meal_schedules", "communities"
  add_foreign_key "meal_schedules", "users", column: "created_by_id"
  add_foreign_key "meals", "communities"
  add_foreign_key "meals", "meal_schedules"
  add_foreign_key "meals", "users", column: "created_by_id"
  add_foreign_key "meals", "users", column: "deleted_by_id"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "recurring_tasks", "communities"
  add_foreign_key "recurring_tasks", "users", column: "created_by_id"
  add_foreign_key "recurring_tasks", "users", column: "default_responsible_user_id"
  add_foreign_key "recurring_tasks", "workstreams"
  add_foreign_key "tasks", "communities"
  add_foreign_key "tasks", "recurring_tasks"
  add_foreign_key "tasks", "users"
  add_foreign_key "tasks", "users", column: "assigned_to_user_id"
  add_foreign_key "tasks", "users", column: "completed_by_id"
  add_foreign_key "tasks", "users", column: "created_by_id"
  add_foreign_key "tasks", "users", column: "deleted_by_id"
  add_foreign_key "tasks", "users", column: "released_by_id"
  add_foreign_key "tasks", "workstreams"
  add_foreign_key "users", "communities"
  add_foreign_key "users", "households"
  add_foreign_key "users", "invitations"
  add_foreign_key "workstreams", "communities"
  add_foreign_key "workstreams", "users", column: "owner_id"
end
