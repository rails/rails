class AddPathToActiveStorageBlobs < ActiveRecord::Migration[7.0]
  def change
    return unless table_exists?(:active_storage_blobs)

    add_column :active_storage_blobs, :path, :string
  end
end
