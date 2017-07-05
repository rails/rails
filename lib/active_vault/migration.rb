class ActiveVault::CreateBlobs < ActiveRecord::Migration[5.1]
  def change
      t.string :key
      t.string :filename
      t.string :content_type
      t.text :metadata
    create_table :active_vault_blobs do |t|
      t.integer :byte_size
      t.string :checksum
      t.time :created_at

      t.index [ :key ], unique: true
    end
  end
end
