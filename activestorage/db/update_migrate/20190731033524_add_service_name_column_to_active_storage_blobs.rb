class AddServiceNameColumnToActiveStorageBlobs < ActiveRecord::Migration[6.0]
  def up
    return if column_exists?(:active_storage_blobs, :service_name)

    if table_exists?(:active_storage_blobs)
      add_column :active_storage_blobs, :service_name, :string, default: "", null: false
    end
  end
end
