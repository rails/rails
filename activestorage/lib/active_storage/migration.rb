class ActiveStorageCreateTables < ActiveRecord::Migration[5.1]
  def change
    create_table :active_storage_blobs do |t|
      t.string   :key
      t.string   :filename
      t.string   :content_type
      t.text     :metadata
      t.integer  :byte_size
      t.string   :checksum
      t.datetime :created_at

      t.index [ :key ], unique: true
    end

    create_table :active_storage_attachments do |t|
      t.string  :name
      t.string  :record_type
      t.integer :record_id
      t.integer :blob_id

      t.datetime :created_at

      t.index :blob_id
      t.index [ :record_type, :record_id, :name, :blob_id ], name: "index_active_storage_attachments_uniqueness", unique: true
    end
  end
end
