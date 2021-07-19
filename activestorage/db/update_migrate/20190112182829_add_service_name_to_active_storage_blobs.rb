class AddServiceNameToActiveStorageBlobs < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    unless column_exists?(:active_storage_blobs, :service_name)
      add_column :active_storage_blobs, :service_name, :string
    end

    if (configured_service = ActiveStorage::Blob.service.name && blobs_without_service_name.count > 0)
      say_with_time("backfill ActiveStorage::Blob.service.name. This could take a while…") do
        blobs_without_service_name.in_batches do |relation|
          relation.update_all service_name: configured_service
          sleep(0.01) # throttle
        end
      end
    end

    unless column_exists?(:active_storage_blobs, :service_name, null: false)
      ActiveStorage::Blob.transaction do
        # Ensure all service_name values are filled (in case other app instances
        # not upgraded to ActiveStorage 6.1 yet created records with nil service_name
        # while we where backfilling the column).
        blobs_without_service_name.update_all service_name: configured_service

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
  end

  def down
    remove_column :active_storage_blobs, :service_name
  end

  private
    def blobs_without_service_name
      ActiveStorage::Blob.unscoped.where(service_name: nil)
    end
end
