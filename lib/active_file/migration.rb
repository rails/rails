class ActiveFile::CreateBlobs < ActiveRecord::Migration[5.2]
  def change
    create_table :rails_active_file_blobs do |t|
      t.string :token
      t.string :filename
      t.string :content_type
      t.integer :byte_size
      t.string :digest
      t.time :created_at

      t.index [ :token ], unique: true
    end
  end
end
