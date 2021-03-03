class AddServiceNameToActiveStorageBlobs < ActiveRecord::Migration[6.0]
  def up
    unless column_exists?(:active_storage_blobs, :service_name)
      add_column :active_storage_blobs, :service_name, :string

      if configured_service = ActiveStorage::Blob.service.name
        ActiveStorage::Blob.unscoped.update_all(service_name: configured_service)
      end

      ActiveStorage::Blob.reset_column_information

      change_column :active_storage_blobs, :service_name, :string, null: false
    end
  end

  def down
    remove_column :active_storage_blobs, :service_name
  end
end
