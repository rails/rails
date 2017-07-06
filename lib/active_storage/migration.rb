class ActiveStorageCreateTables < ActiveRecord::Migration[5.1]
  def change
    create_table :active_storage_blobs do |t|
      t.string  :key
      t.string  :filename
      t.string  :content_type
      t.text    :metadata
      t.integer :byte_size
      t.string  :checksum
      t.time    :created_at

      t.index [ :key ], unique: true
    end

    create_table :active_storage_attachments do |t|
      t.string  :name
      t.string  :record_gid
      t.integer :blob_id

      t.time :created_at

      t.index :record_gid
      t.index :blob_id
      t.index [ :record_gid, :name ]
      t.index [ :record_gid, :blob_id ], unique: true
    end
  end
end
