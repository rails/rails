class AddForeignKeyConstraintToActiveStorageAttachmentsForBlobId < ActiveRecord::Migration[6.0]
  def up
    return if foreign_key_exists?(:active_storage_attachments, column: :blob_id)

    if table_exists?(:active_storage_blobs)
      add_foreign_key :active_storage_attachments, :active_storage_blobs, column: :blob_id
    end
  end
end
