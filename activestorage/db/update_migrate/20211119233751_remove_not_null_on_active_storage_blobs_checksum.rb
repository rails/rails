class RemoveNotNullOnActiveStorageBlobsChecksum < ActiveRecord::Migration[6.0]
  def change
    change_column_null(:active_storage_blobs, :checksum, true)
  end
end
