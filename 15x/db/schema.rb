# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20151215112417) do

  create_table "accesskeys", force: :cascade do |t|
    t.integer  "user_id",    limit: 4
    t.string   "secret_key", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "accounts", force: :cascade do |t|
    t.string   "username",   limit: 255
    t.string   "password",   limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "contributors", force: :cascade do |t|
    t.integer  "user_id",        limit: 4
    t.integer  "subreddit_id",   limit: 4
    t.datetime "date"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "tooltip_suffix", limit: 255
    t.string   "display_name",   limit: 255
  end

  add_index "contributors", ["subreddit_id"], name: "subreddit_id", using: :btree
  add_index "contributors", ["user_id", "subreddit_id"], name: "user_id_and_subreddit_id_unique", unique: true, using: :btree

  create_table "cryptokeys", force: :cascade do |t|
    t.integer  "subreddit_id", limit: 4
    t.string   "secret_key",   limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "cryptokeys", ["subreddit_id"], name: "subreddit_id", using: :btree

  create_table "gildings", force: :cascade do |t|
    t.string   "kind",         limit: 255
    t.string   "name",         limit: 255
    t.integer  "subreddit_id", limit: 4
    t.integer  "user_id",      limit: 4
    t.string   "url",          limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "created_utc",  limit: 8
    t.integer  "gilded",       limit: 4
  end

  add_index "gildings", ["subreddit_id"], name: "subreddit_id", using: :btree
  add_index "gildings", ["user_id"], name: "user_id", using: :btree

  create_table "subreddits", force: :cascade do |t|
    t.string   "name",                      limit: 255
    t.string   "display_name",              limit: 255
    t.string   "override_display_name",     limit: 255
    t.integer  "chain_number",              limit: 4
    t.integer  "spriteset_position",        limit: 4
    t.boolean  "monitor_contributors",                    default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "user_list_updated_at"
    t.boolean  "name_is_secret",                          default: false, null: false
    t.string   "crypto",                    limit: 255
    t.string   "access_secret",             limit: 255
    t.integer  "account_id",                limit: 4,                     null: false
    t.integer  "monitor_gildings",          limit: 1,     default: 0,     null: false
    t.datetime "gildings_updated_at"
    t.string   "icon_default_file_name",    limit: 255
    t.string   "icon_default_content_type", limit: 255
    t.integer  "icon_default_file_size",    limit: 4
    t.datetime "icon_default_updated_at"
    t.string   "icon_current_file_name",    limit: 255
    t.string   "icon_current_content_type", limit: 255
    t.integer  "icon_current_file_size",    limit: 4
    t.datetime "icon_current_updated_at"
    t.string   "icon_higher_file_name",     limit: 255
    t.string   "icon_higher_content_type",  limit: 255
    t.integer  "icon_higher_file_size",     limit: 4
    t.datetime "icon_higher_updated_at"
    t.string   "encoded_icon_default",      limit: 16384
    t.string   "encoded_icon_current",      limit: 16384
    t.string   "encoded_icon_higher",       limit: 16384
  end

  create_table "users", force: :cascade do |t|
    t.string   "name",                 limit: 255
    t.string   "display_name",         limit: 255
    t.datetime "installation_seen_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "ninja_pirate_visible",             default: false, null: false
  end

end
