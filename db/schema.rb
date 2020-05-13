# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_05_13_145310) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "account_sources", id: :serial, force: :cascade do |t|
    t.integer "account_id"
    t.integer "source_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "source_id"], name: "index_account_sources_on_account_id_and_source_id", unique: true
    t.index ["source_id"], name: "index_account_sources_on_source_id"
  end

  create_table "accounts", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "team_id"
    t.text "omniauth_info"
    t.string "uid"
    t.string "provider"
    t.string "token"
    t.string "email"
    t.index ["uid", "provider", "token", "email"], name: "index_accounts_on_uid_and_provider_and_token_and_email"
    t.index ["url"], name: "index_accounts_on_url", unique: true
  end

  create_table "annotations", id: :serial, force: :cascade do |t|
    t.string "annotation_type", null: false
    t.integer "version_index"
    t.string "annotated_type"
    t.integer "annotated_id"
    t.string "annotator_type"
    t.integer "annotator_id"
    t.text "entities"
    t.text "data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "file"
    t.text "attribution"
    t.integer "lock_version", default: 0, null: false
    t.boolean "locked", default: false
    t.text "fragment"
    t.index "task_team_task_id((annotation_type)::text, data)", name: "task_team_task_id", where: "((annotation_type)::text = 'task'::text)"
    t.index ["annotated_type", "annotated_id"], name: "index_annotations_on_annotated_type_and_annotated_id"
    t.index ["annotation_type"], name: "index_annotation_type_order"
    t.index ["annotation_type"], name: "index_annotations_on_annotation_type"
  end

  create_table "api_keys", id: :serial, force: :cascade do |t|
    t.string "access_token", default: "", null: false
    t.datetime "expire_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "application"
  end

  create_table "assignments", id: :serial, force: :cascade do |t|
    t.integer "assigned_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "assigned_type"
    t.integer "assigner_id"
    t.index ["assigned_id", "assigned_type", "user_id"], name: "index_assignments_on_assigned_id_and_assigned_type_and_user_id", unique: true
    t.index ["assigned_id", "assigned_type"], name: "index_assignments_on_assigned_id_and_assigned_type"
    t.index ["assigned_id"], name: "index_assignments_on_assigned_id"
    t.index ["assigned_type"], name: "index_assignments_on_assigned_type"
    t.index ["assigner_id"], name: "index_assignments_on_assigner_id"
    t.index ["user_id"], name: "index_assignments_on_user_id"
  end

  create_table "bounces", id: :serial, force: :cascade do |t|
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_bounces_on_email", unique: true
  end

  create_table "claim_sources", id: :serial, force: :cascade do |t|
    t.integer "media_id"
    t.integer "source_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["media_id", "source_id"], name: "index_claim_sources_on_media_id_and_source_id", unique: true
  end

  create_table "contacts", id: :serial, force: :cascade do |t|
    t.integer "team_id"
    t.string "location"
    t.string "phone"
    t.string "web"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "dynamic_annotation_annotation_types", primary_key: "annotation_type", id: :string, force: :cascade do |t|
    t.string "label", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "singleton", default: true
    t.jsonb "json_schema", default: {}
    t.index ["json_schema"], name: "index_dynamic_annotation_annotation_types_on_json_schema", using: :gin
  end

  create_table "dynamic_annotation_field_instances", primary_key: "name", id: :string, force: :cascade do |t|
    t.string "field_type", null: false
    t.string "annotation_type", null: false
    t.string "label", null: false
    t.text "description"
    t.boolean "optional", default: true
    t.text "settings"
    t.string "default_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "dynamic_annotation_field_types", primary_key: "field_type", id: :string, force: :cascade do |t|
    t.string "label", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "dynamic_annotation_fields", id: :serial, force: :cascade do |t|
    t.integer "annotation_id", null: false
    t.string "field_name", null: false
    t.string "annotation_type", null: false
    t.string "field_type", null: false
    t.text "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "value_json", default: {}
    t.index ["annotation_id"], name: "index_dynamic_annotation_fields_on_annotation_id"
    t.index ["field_type"], name: "index_dynamic_annotation_fields_on_field_type"
    t.index ["value"], name: "translation_request_id", unique: true, where: "((field_name)::text = 'translation_request_id'::text)"
    t.index ["value_json"], name: "index_dynamic_annotation_fields_on_value_json", using: :gin
  end

  create_table "login_activities", id: :serial, force: :cascade do |t|
    t.string "scope"
    t.string "strategy"
    t.string "identity"
    t.boolean "success"
    t.string "failure_reason"
    t.string "user_type"
    t.integer "user_id"
    t.string "context"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.datetime "created_at"
    t.index ["identity"], name: "index_login_activities_on_identity"
    t.index ["ip"], name: "index_login_activities_on_ip"
  end

  create_table "medias", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "account_id"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "quote"
    t.string "type"
    t.string "file"
    t.index ["id"], name: "index_medias_on_id"
    t.index ["url"], name: "index_medias_on_url", unique: true
  end

  create_table "pghero_query_stats", id: :serial, force: :cascade do |t|
    t.text "database"
    t.text "user"
    t.text "query"
    t.bigint "query_hash"
    t.float "total_time"
    t.bigint "calls"
    t.datetime "captured_at"
    t.index ["database", "captured_at"], name: "index_pghero_query_stats_on_database_and_captured_at"
  end

  create_table "project_media_projects", id: :serial, force: :cascade do |t|
    t.integer "project_media_id"
    t.integer "project_id"
    t.index ["project_id"], name: "index_project_media_projects_on_project_id"
    t.index ["project_media_id", "project_id"], name: "index_project_media_projects_on_project_media_id_and_project_id", unique: true
    t.index ["project_media_id"], name: "index_project_media_projects_on_project_media_id"
  end

  create_table "project_medias", id: :serial, force: :cascade do |t|
    t.integer "project_id"
    t.integer "media_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.integer "cached_annotations_count", default: 0
    t.boolean "archived", default: false
    t.integer "targets_count", default: 0, null: false
    t.integer "sources_count", default: 0, null: false
    t.boolean "inactive", default: false
    t.integer "team_id"
    t.index ["id"], name: "index_project_medias_on_id"
    t.index ["inactive"], name: "index_project_medias_on_inactive"
    t.index ["media_id"], name: "index_project_medias_on_media_id"
    t.index ["project_id", "media_id"], name: "index_project_medias_on_project_id_and_media_id", unique: true
    t.index ["team_id"], name: "index_project_medias_on_team_id"
  end

  create_table "project_sources", id: :serial, force: :cascade do |t|
    t.integer "project_id"
    t.integer "source_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.integer "cached_annotations_count", default: 0
    t.index ["project_id", "source_id"], name: "index_project_sources_on_project_id_and_source_id", unique: true
  end

  create_table "projects", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "team_id"
    t.string "title"
    t.text "description"
    t.string "lead_image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "archived", default: false
    t.text "settings"
    t.string "token"
    t.integer "assignments_count", default: 0
    t.index ["id"], name: "index_projects_on_id"
    t.index ["team_id"], name: "index_projects_on_team_id"
    t.index ["token"], name: "index_projects_on_token", unique: true
  end

  create_table "relationships", id: :serial, force: :cascade do |t|
    t.integer "source_id", null: false
    t.integer "target_id", null: false
    t.string "relationship_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["source_id", "target_id", "relationship_type"], name: "relationship_index", unique: true
  end

  create_table "shortened_urls", id: :serial, force: :cascade do |t|
    t.integer "owner_id"
    t.string "owner_type", limit: 20
    t.text "url", null: false
    t.string "unique_key", limit: 10, null: false
    t.string "category"
    t.integer "use_count", default: 0, null: false
    t.datetime "expires_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["category"], name: "index_shortened_urls_on_category"
    t.index ["owner_id", "owner_type"], name: "index_shortened_urls_on_owner_id_and_owner_type"
    t.index ["unique_key"], name: "index_shortened_urls_on_unique_key", unique: true
    t.index ["url"], name: "index_shortened_urls_on_url"
  end

  create_table "sources", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "name"
    t.string "slogan"
    t.string "avatar"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "team_id"
    t.string "file"
    t.boolean "archived", default: false
    t.integer "lock_version", default: 0, null: false
  end

  create_table "tag_texts", id: :serial, force: :cascade do |t|
    t.string "text", null: false
    t.integer "team_id", null: false
    t.integer "tags_count", default: 0
    t.boolean "teamwide", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["text", "team_id"], name: "index_tag_texts_on_text_and_team_id", unique: true
  end

  create_table "team_tasks", id: :serial, force: :cascade do |t|
    t.string "label", null: false
    t.string "task_type", null: false
    t.text "description"
    t.text "options"
    t.text "project_ids"
    t.text "mapping"
    t.boolean "required", default: false
    t.integer "team_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "json_schema"
  end

  create_table "team_users", id: :serial, force: :cascade do |t|
    t.integer "team_id"
    t.integer "user_id"
    t.string "type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role"
    t.string "status", default: "member"
    t.text "settings"
    t.integer "invited_by_id"
    t.string "invitation_token"
    t.string "raw_invitation_token"
    t.datetime "invitation_accepted_at"
    t.string "invitation_email"
    t.index ["id"], name: "index_team_users_on_id"
    t.index ["team_id", "user_id"], name: "index_team_users_on_team_id_and_user_id", unique: true
    t.index ["type"], name: "index_team_users_on_type"
    t.index ["user_id", "team_id"], name: "index_team_users_on_user_id_and_team_id"
  end

  create_table "teams", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "logo"
    t.boolean "private", default: true
    t.boolean "archived", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.string "slug"
    t.text "settings"
    t.boolean "inactive", default: false
    t.index ["id"], name: "index_teams_on_id"
    t.index ["inactive"], name: "index_teams_on_inactive"
    t.index ["slug"], name: "index_teams_on_slug"
    t.index ["slug"], name: "unique_team_slugs", unique: true
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "login", default: "", null: false
    t.string "token", default: "", null: false
    t.string "email"
    t.string "encrypted_password", default: ""
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "image"
    t.integer "current_team_id"
    t.text "settings"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.boolean "is_admin", default: false
    t.text "cached_teams"
    t.string "type"
    t.integer "api_key_id"
    t.integer "source_id"
    t.string "unconfirmed_email"
    t.integer "current_project_id"
    t.boolean "is_active", default: true
    t.string "invitation_token"
    t.string "raw_invitation_token"
    t.datetime "invitation_created_at"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer "invitation_limit"
    t.integer "invited_by_id"
    t.string "invited_by_type"
    t.datetime "last_accepted_terms_at"
    t.string "encrypted_otp_secret"
    t.string "encrypted_otp_secret_iv"
    t.string "encrypted_otp_secret_salt"
    t.integer "consumed_timestep"
    t.boolean "otp_required_for_login"
    t.string "otp_backup_codes", array: true
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email"
    t.index ["id"], name: "index_users_on_id"
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["source_id"], name: "index_users_on_source_id"
    t.index ["token"], name: "index_users_on_token", unique: true
    t.index ["type"], name: "index_users_on_type"
  end

  create_table "versions", id: :serial, force: :cascade do |t|
    t.string "item_type", null: false
    t.string "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.text "object_changes"
    t.datetime "created_at"
    t.text "meta"
    t.string "event_type"
    t.text "object_after"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "team_id"
    t.index ["associated_id"], name: "index_versions_on_associated_id"
    t.index ["event_type"], name: "index_versions_on_event_type"
    t.index ["item_type", "item_id", "whodunnit"], name: "index_versions_on_item_type_and_item_id_and_whodunnit"
    t.index ["team_id"], name: "index_versions_on_team_id"
  end

end
