# This migration comes from solid_cache (originally 20240820123641)
class CreateSolidCacheEntries < ActiveRecord::Migration[7.2]
  def up
    create_table :solid_cache_entries, if_not_exists: true do |t|
      t.binary   :key,        null: false,   limit: 1024
      t.binary   :value,      null: false,   limit: 512.megabytes
      t.datetime :created_at, null: false
      t.integer :key_hash,    null: false,    limit: 8
      t.integer :byte_size,   null: false,    limit: 4

      t.index  :key_hash, unique: true
      t.index  [:key_hash, :byte_size]
      t.index  :byte_size
    end

    raise "column \"key_hash\" does not exist" unless column_exists? :solid_cache_entries, :key_hash
  rescue => e
    if e.message =~ /(column "key_hash" does not exist|no such column: key_hash)/
      raise \
        "Could not find key_hash column on solid_cache_entries, if upgrading from v0.3 or earlier, have you followed " \
        "the steps in https://github.com/rails/solid_cache/blob/main/upgrading_to_version_0.4.x.md?"
    else
      raise
    end
  end

  def down
    drop_table :solid_cache_entries
  end
end
