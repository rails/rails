class RemoveNotNullOnActiveStorageBlobsChecksum < ActiveRecord::Migration[6.0]
  def change
    return unless table_exists?(:active_storage_blobs)

    change_column_null(:active_storage_blobs, :checksum, true)
  end
end
