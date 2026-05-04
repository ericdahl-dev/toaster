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

ActiveRecord::Schema[7.2].define(version: 2026_05_04_160000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "agentmail_connections", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "inbox_id", null: false
    t.text "api_key", null: false
    t.boolean "active", default: true, null: false
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "inbox_id"], name: "index_agentmail_connections_on_account_id_and_inbox_id", unique: true
    t.index ["account_id"], name: "index_agentmail_connections_on_account_id"
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
    t.bigint "source_inbox_message_id"
    t.jsonb "extraction_snapshot", default: {}, null: false
    t.jsonb "missing_fields", default: [], null: false
    t.jsonb "review_reasons", default: [], null: false
    t.index ["account_id"], name: "index_booking_requests_on_account_id"
    t.index ["contact_id"], name: "index_booking_requests_on_contact_id"
    t.index ["conversation_thread_id"], name: "index_booking_requests_on_conversation_thread_id"
    t.index ["source_inbox_message_id"], name: "index_booking_requests_on_source_inbox_message_id", unique: true
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
    t.index ["account_id", "email"], name: "index_contacts_on_account_id_and_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["account_id"], name: "index_contacts_on_account_id"
  end

  create_table "conversation_threads", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "contact_id", null: false
    t.string "provider_thread_id", null: false
    t.string "subject"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "provider_thread_id"], name: "idx_on_account_id_provider_thread_id_f9411ec04c", unique: true
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

  create_table "imap_connections", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "host", null: false
    t.integer "port", default: 993, null: false
    t.boolean "ssl", default: true, null: false
    t.string "username", null: false
    t.text "password"
    t.string "inbox_folder", default: "INBOX", null: false
    t.integer "last_synced_uid"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "username", "host"], name: "index_imap_connections_on_account_username_host", unique: true
    t.index ["account_id"], name: "index_imap_connections_on_account_id"
  end

  create_table "inbox_messages", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "provider", null: false
    t.string "provider_message_id", null: false
    t.string "provider_thread_id"
    t.string "direction", default: "inbound", null: false
    t.string "from_name"
    t.string "from_email"
    t.jsonb "to_emails", default: [], null: false
    t.string "subject"
    t.text "body_text"
    t.text "body_html"
    t.datetime "received_at"
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "provider", "provider_message_id"], name: "idx_inbox_messages_unique_provider_message", unique: true
    t.index ["account_id", "provider_thread_id"], name: "idx_inbox_messages_on_account_and_thread"
    t.index ["account_id"], name: "index_inbox_messages_on_account_id"
    t.index ["direction"], name: "index_inbox_messages_on_direction"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "conversation_thread_id", null: false
    t.bigint "booking_request_id"
    t.string "direction", null: false
    t.string "provider_message_id"
    t.text "body_text"
    t.text "body_html"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "provider_message_id"], name: "index_messages_on_account_id_and_provider_message_id", unique: true, where: "(provider_message_id IS NOT NULL)"
    t.index ["account_id"], name: "index_messages_on_account_id"
    t.index ["booking_request_id"], name: "index_messages_on_booking_request_id"
    t.index ["conversation_thread_id"], name: "index_messages_on_conversation_thread_id"
    t.index ["direction"], name: "index_messages_on_direction"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
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
    t.string "password_digest", null: false
    t.string "remember_token_digest"
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email"], name: "index_users_on_email", unique: true
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

  add_foreign_key "agentmail_connections", "accounts"
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
  add_foreign_key "inbox_messages", "accounts"
  add_foreign_key "messages", "accounts"
  add_foreign_key "messages", "booking_requests"
  add_foreign_key "messages", "conversation_threads"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tasks", "accounts"
  add_foreign_key "tasks", "booking_requests"
  add_foreign_key "users", "accounts"
  add_foreign_key "venues", "accounts"
end
