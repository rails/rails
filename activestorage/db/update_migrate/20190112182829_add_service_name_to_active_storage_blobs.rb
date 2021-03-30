class AddServiceNameToActiveStorageBlobs < ActiveRecord::Migration[6.0]
  def up
    unless column_exists?(:active_storage_blobs, :service_name)
      add_column :active_storage_blobs, :service_name, :string

      if configured_service = ActiveStorage::Blob.service.name
        # Fill the initial value for service_name.
        #
        # N.B: the database will be locked during the whole update.
        # Depending on the number of Blob records in the database, this can be
        # quite slow.
        # If this is an issue for you, you should edit this migration
        # (for instance by updating the records incrementally).
        ActiveStorage::Blob.unscoped.update_all(service_name: configured_service)
      end

      # Mark the column as not nullable.
      #
      # N.B: any other app instances not upgraded to ActiveStorage 6.1 yet will
      # be unable to create new Blobs until they are upgraded.
      # If this is an issue for you, you should edit this migration
      # (for instance by moving the non-nullable change to a separate migration,
      # that will run after all instances are upgraded to ActiveStorage 6.1).
      change_column :active_storage_blobs, :service_name, :string, null: false
    end
  end

  def down
    remove_column :active_storage_blobs, :service_name
  end
end
