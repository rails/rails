class AddServiceNameToActiveStorageBlobs < ActiveRecord::Migration[6.0]
  def up
    return unless table_exists?(ActiveStorage::Blob.table_name)

    unless column_exists?(ActiveStorage::Blob.table_name, :service_name)
      add_column ActiveStorage::Blob.table_name, :service_name, :string

      if configured_service = ActiveStorage::Blob.service.name
        ActiveStorage::Blob.unscoped.update_all(service_name: configured_service)
      end

      change_column ActiveStorage::Blob.table_name, :service_name, :string, null: false
    end
  end

  def down
    return unless table_exists?(ActiveStorage::Blob.table_name)

    remove_column ActiveStorage::Blob.table_name, :service_name
  end
end
