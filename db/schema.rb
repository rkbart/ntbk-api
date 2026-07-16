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

ActiveRecord::Schema[8.1].define(version: 2026_07_16_052907) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

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

  create_table "attachments", force: :cascade do |t|
    t.string "content_type", null: false
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.bigint "file_size", null: false
    t.string "filename", null: false
    t.jsonb "metadata", default: {}
    t.string "preview_state", default: "pending"
    t.datetime "updated_at", null: false
    t.index ["content_type"], name: "index_attachments_on_content_type"
    t.index ["document_id"], name: "index_attachments_on_document_id"
    t.index ["preview_state"], name: "index_attachments_on_preview_state"
  end

  create_table "document_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.bigint "tag_id", null: false
    t.index ["document_id", "tag_id"], name: "index_document_tags_on_document_id_and_tag_id", unique: true
    t.index ["document_id"], name: "index_document_tags_on_document_id"
    t.index ["tag_id"], name: "index_document_tags_on_tag_id"
  end

  create_table "documents", force: :cascade do |t|
    t.datetime "archived_at"
    t.integer "attachments_count", default: 0, null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "folder_id"
    t.tsvector "search_vector"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["folder_id"], name: "index_documents_on_folder_id"
    t.index ["search_vector"], name: "index_documents_on_search_vector", using: :gin
    t.index ["title", "body"], name: "index_documents_on_title_body_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["workspace_id", "archived_at"], name: "index_documents_on_workspace_id_and_archived_at"
    t.index ["workspace_id", "folder_id"], name: "index_documents_on_workspace_id_and_folder_id"
    t.index ["workspace_id"], name: "index_documents_on_workspace_id"
  end

  create_table "folders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.bigint "workspace_id", null: false
    t.index ["parent_id"], name: "index_folders_on_parent_id"
    t.index ["workspace_id", "parent_id"], name: "index_folders_on_workspace_id_and_parent_id"
    t.index ["workspace_id"], name: "index_folders_on_workspace_id"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_tags_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_tags_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workspaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_workspaces_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attachments", "documents"
  add_foreign_key "document_tags", "documents"
  add_foreign_key "document_tags", "tags"
  add_foreign_key "documents", "folders"
  add_foreign_key "documents", "workspaces"
  add_foreign_key "folders", "folders", column: "parent_id"
  add_foreign_key "folders", "workspaces"
  add_foreign_key "tags", "users"
  add_foreign_key "workspaces", "users"
end
