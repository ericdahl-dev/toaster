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

ActiveRecord::Schema[8.1].define(version: 2026_05_09_150639) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ai_runs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "booking_request_id"
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.string "llm_model", null: false
    t.integer "output_tokens"
    t.text "prompt", null: false
    t.text "response"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_ai_runs_on_account_id"
    t.index ["booking_request_id"], name: "index_ai_runs_on_booking_request_id"
  end

  create_table "booking_requests", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "budget_cents"
    t.bigint "contact_id", null: false
    t.bigint "conversation_thread_id", null: false
    t.datetime "created_at", null: false
    t.date "event_date"
    t.date "event_end_date"
    t.jsonb "extraction_snapshot", default: {}, null: false
    t.integer "headcount"
    t.jsonb "missing_fields", default: [], null: false
    t.text "notes"
    t.jsonb "review_reasons", default: [], null: false
    t.bigint "source_inbox_message_id"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "venue_id"
    t.index ["account_id"], name: "index_booking_requests_on_account_id"
    t.index ["contact_id"], name: "index_booking_requests_on_contact_id"
    t.index ["conversation_thread_id"], name: "index_booking_requests_on_conversation_thread_id"
    t.index ["source_inbox_message_id"], name: "index_booking_requests_on_source_inbox_message_id", unique: true
    t.index ["status"], name: "index_booking_requests_on_status"
    t.index ["venue_id"], name: "index_booking_requests_on_venue_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.citext "email"
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_contacts_on_account_id_and_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["account_id"], name: "index_contacts_on_account_id"
  end

  create_table "conversation_threads", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "contact_id", null: false
    t.datetime "created_at", null: false
    t.string "provider_thread_id", null: false
    t.string "subject"
    t.datetime "updated_at", null: false
    t.index ["account_id", "provider_thread_id"], name: "idx_on_account_id_provider_thread_id_f9411ec04c", unique: true
    t.index ["account_id"], name: "index_conversation_threads_on_account_id"
    t.index ["contact_id"], name: "index_conversation_threads_on_contact_id"
  end

  create_table "drafts", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.text "body", null: false
    t.bigint "booking_request_id", null: false
    t.datetime "created_at", null: false
    t.integer "imap_draft_uid"
    t.text "original_body"
    t.datetime "sent_at"
    t.string "status", default: "pending_review", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_drafts_on_account_id"
    t.index ["booking_request_id"], name: "index_drafts_on_booking_request_id"
    t.index ["status"], name: "index_drafts_on_status"
  end

  create_table "event_logs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.bigint "subject_id"
    t.string "subject_type"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_event_logs_on_account_id"
    t.index ["event_type"], name: "index_event_logs_on_event_type"
    t.index ["subject_type", "subject_id"], name: "index_event_logs_on_subject_type_and_subject_id"
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "callback_priority"
    t.text "callback_queue_name"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
    t.text "on_discard"
    t.text "on_finish"
    t.text "on_success"
    t.jsonb "serialized_properties"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id", null: false
    t.datetime "created_at", null: false
    t.interval "duration"
    t.text "error"
    t.text "error_backtrace", array: true
    t.integer "error_event", limit: 2
    t.datetime "finished_at"
    t.text "job_class"
    t.uuid "process_id"
    t.text "queue_name"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lock_type", limit: 2
    t.jsonb "state"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "key"
    t.datetime "updated_at", null: false
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id"
    t.uuid "batch_callback_id"
    t.uuid "batch_id"
    t.text "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "cron_at"
    t.text "cron_key"
    t.text "error"
    t.integer "error_event", limit: 2
    t.integer "executions_count"
    t.datetime "finished_at"
    t.boolean "is_discrete"
    t.text "job_class"
    t.text "labels", array: true
    t.integer "lock_type", limit: 2
    t.datetime "locked_at"
    t.uuid "locked_by_id"
    t.datetime "performed_at"
    t.integer "priority"
    t.text "queue_name"
    t.uuid "retried_good_job_id"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["created_at"], name: "index_good_jobs_on_created_at"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_on_discarded", order: :desc, where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["id"], name: "index_good_jobs_on_unfinished_or_errored", where: "((finished_at IS NULL) OR (error IS NOT NULL))"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_for_candidate_dequeue_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_on_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at", "id"], name: "index_good_jobs_on_queue_name_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["queue_name"], name: "index_good_jobs_on_queue_name"
    t.index ["scheduled_at", "queue_name"], name: "index_good_jobs_on_scheduled_at_and_queue_name"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "imap_connections", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "host", null: false
    t.string "inbox_folder", default: "INBOX", null: false
    t.integer "last_synced_uid"
    t.text "password"
    t.integer "port", default: 993, null: false
    t.string "smtp_host"
    t.integer "smtp_port"
    t.boolean "ssl", default: true, null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["account_id", "username", "host"], name: "index_imap_connections_on_account_username_host", unique: true
    t.index ["account_id"], name: "index_imap_connections_on_account_id"
  end

  create_table "inbox_filters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "imap_connection_id", null: false
    t.string "keyword", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "venue_id", null: false
    t.index ["imap_connection_id"], name: "index_inbox_filters_on_imap_connection_id"
    t.index ["venue_id"], name: "index_inbox_filters_on_venue_id"
  end

  create_table "inbox_messages", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.text "body_html"
    t.text "body_text"
    t.datetime "created_at", null: false
    t.string "direction", default: "inbound", null: false
    t.string "from_email"
    t.string "from_name"
    t.string "provider", null: false
    t.string "provider_message_id", null: false
    t.string "provider_thread_id"
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "received_at"
    t.string "subject"
    t.jsonb "to_emails", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "provider", "provider_message_id"], name: "idx_inbox_messages_unique_provider_message", unique: true
    t.index ["account_id", "provider_thread_id"], name: "idx_inbox_messages_on_account_and_thread"
    t.index ["account_id"], name: "index_inbox_messages_on_account_id"
    t.index ["direction"], name: "index_inbox_messages_on_direction"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.text "body_html"
    t.text "body_text"
    t.bigint "booking_request_id"
    t.bigint "conversation_thread_id", null: false
    t.datetime "created_at", null: false
    t.string "direction", null: false
    t.string "provider_message_id"
    t.datetime "sent_at"
    t.datetime "updated_at", null: false
    t.index ["account_id", "provider_message_id"], name: "index_messages_on_account_id_and_provider_message_id", unique: true, where: "(provider_message_id IS NOT NULL)"
    t.index ["account_id"], name: "index_messages_on_account_id"
    t.index ["booking_request_id"], name: "index_messages_on_booking_request_id"
    t.index ["conversation_thread_id"], name: "index_messages_on_conversation_thread_id"
    t.index ["direction"], name: "index_messages_on_direction"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "booking_request_id", null: false
    t.datetime "created_at", null: false
    t.datetime "due_at"
    t.string "status", default: "open", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_tasks_on_account_id"
    t.index ["booking_request_id"], name: "index_tasks_on_booking_request_id"
    t.index ["status"], name: "index_tasks_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.citext "email", null: false
    t.string "encrypted_password", null: false
    t.string "name", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "venues", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "address"
    t.integer "capacity"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_venues_on_account_id"
  end

  add_foreign_key "ai_runs", "accounts"
  add_foreign_key "ai_runs", "booking_requests"
  add_foreign_key "booking_requests", "accounts"
  add_foreign_key "booking_requests", "contacts"
  add_foreign_key "booking_requests", "conversation_threads"
  add_foreign_key "booking_requests", "inbox_messages", column: "source_inbox_message_id"
  add_foreign_key "booking_requests", "venues"
  add_foreign_key "contacts", "accounts"
  add_foreign_key "conversation_threads", "accounts"
  add_foreign_key "conversation_threads", "contacts"
  add_foreign_key "drafts", "accounts"
  add_foreign_key "drafts", "booking_requests"
  add_foreign_key "event_logs", "accounts"
  add_foreign_key "imap_connections", "accounts"
  add_foreign_key "inbox_filters", "imap_connections"
  add_foreign_key "inbox_filters", "venues"
  add_foreign_key "inbox_messages", "accounts"
  add_foreign_key "messages", "accounts"
  add_foreign_key "messages", "booking_requests"
  add_foreign_key "messages", "conversation_threads"
  add_foreign_key "tasks", "accounts"
  add_foreign_key "tasks", "booking_requests"
  add_foreign_key "users", "accounts"
  add_foreign_key "venues", "accounts"
end
