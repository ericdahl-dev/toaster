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

ActiveRecord::Schema[7.2].define(version: 2024_01_01_000014) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ai_runs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "booking_request_id"
    t.string "llm_model", null: false
    t.text "prompt", null: false
    t.text "response"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_ai_runs_on_account_id"
    t.index ["booking_request_id"], name: "index_ai_runs_on_booking_request_id"
  end

  create_table "booking_requests", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "conversation_thread_id", null: false
    t.bigint "contact_id", null: false
    t.bigint "venue_id"
    t.string "status", default: "pending", null: false
    t.date "event_date"
    t.date "event_end_date"
    t.integer "headcount"
    t.integer "budget_cents"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_booking_requests_on_account_id"
    t.index ["contact_id"], name: "index_booking_requests_on_contact_id"
    t.index ["conversation_thread_id"], name: "index_booking_requests_on_conversation_thread_id"
    t.index ["status"], name: "index_booking_requests_on_status"
    t.index ["venue_id"], name: "index_booking_requests_on_venue_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.citext "email"
    t.string "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_contacts_on_account_id_and_email"
    t.index ["account_id"], name: "index_contacts_on_account_id"
  end

  create_table "conversation_threads", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "contact_id", null: false
    t.string "gmail_thread_id", null: false
    t.string "subject"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "gmail_thread_id"], name: "index_conversation_threads_on_account_id_and_gmail_thread_id", unique: true
    t.index ["account_id"], name: "index_conversation_threads_on_account_id"
    t.index ["contact_id"], name: "index_conversation_threads_on_contact_id"
  end

  create_table "drafts", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "booking_request_id", null: false
    t.text "body", null: false
    t.string "status", default: "pending_review", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_drafts_on_account_id"
    t.index ["booking_request_id"], name: "index_drafts_on_booking_request_id"
    t.index ["status"], name: "index_drafts_on_status"
  end

  create_table "event_logs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "event_type", null: false
    t.string "subject_type"
    t.bigint "subject_id"
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_event_logs_on_account_id"
    t.index ["event_type"], name: "index_event_logs_on_event_type"
    t.index ["subject_type", "subject_id"], name: "index_event_logs_on_subject_type_and_subject_id"
  end

  create_table "gmail_connections", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "user_id", null: false
    t.citext "email", null: false
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "token_expires_at"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_gmail_connections_on_account_id_and_email", unique: true
    t.index ["account_id"], name: "index_gmail_connections_on_account_id"
    t.index ["user_id"], name: "index_gmail_connections_on_user_id"
  end

  create_table "gmail_webhook_events", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "gmail_history_id"
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_gmail_webhook_events_on_account_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "conversation_thread_id", null: false
    t.bigint "booking_request_id"
    t.string "direction", null: false
    t.string "gmail_message_id"
    t.text "body_text"
    t.text "body_html"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_messages_on_account_id"
    t.index ["booking_request_id"], name: "index_messages_on_booking_request_id"
    t.index ["conversation_thread_id"], name: "index_messages_on_conversation_thread_id"
    t.index ["direction"], name: "index_messages_on_direction"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "booking_request_id", null: false
    t.string "title", null: false
    t.string "status", default: "open", null: false
    t.datetime "due_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_tasks_on_account_id"
    t.index ["booking_request_id"], name: "index_tasks_on_booking_request_id"
    t.index ["status"], name: "index_tasks_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.citext "email", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_users_on_account_id_and_email", unique: true
    t.index ["account_id"], name: "index_users_on_account_id"
  end

  create_table "venues", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.string "address"
    t.integer "capacity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_venues_on_account_id"
  end

  add_foreign_key "ai_runs", "accounts"
  add_foreign_key "ai_runs", "booking_requests"
  add_foreign_key "booking_requests", "accounts"
  add_foreign_key "booking_requests", "contacts"
  add_foreign_key "booking_requests", "conversation_threads"
  add_foreign_key "booking_requests", "venues"
  add_foreign_key "contacts", "accounts"
  add_foreign_key "conversation_threads", "accounts"
  add_foreign_key "conversation_threads", "contacts"
  add_foreign_key "drafts", "accounts"
  add_foreign_key "drafts", "booking_requests"
  add_foreign_key "event_logs", "accounts"
  add_foreign_key "gmail_connections", "accounts"
  add_foreign_key "gmail_connections", "users"
  add_foreign_key "gmail_webhook_events", "accounts"
  add_foreign_key "messages", "accounts"
  add_foreign_key "messages", "booking_requests"
  add_foreign_key "messages", "conversation_threads"
  add_foreign_key "tasks", "accounts"
  add_foreign_key "tasks", "booking_requests"
  add_foreign_key "users", "accounts"
  add_foreign_key "venues", "accounts"
end
