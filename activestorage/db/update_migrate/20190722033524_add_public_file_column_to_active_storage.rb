class AddPublicFileColumnToActiveStorage < ActiveRecord::Migration[5.2]
  def up
    return if column_exists?(:active_storage_blobs, :public_file)

    if table_exists?(:active_storage_blobs)
      add_column :active_storage_blobs, :public_file, :boolean, default: false
    end
  end
end
