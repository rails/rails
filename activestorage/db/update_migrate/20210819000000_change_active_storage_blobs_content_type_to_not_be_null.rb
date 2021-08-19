class CreateActiveStorageVariantRecords < ActiveRecord::Migration[6.1]
  def change
    change_column_null(:active_storage_blobs, :content_type, false)
  end
end
