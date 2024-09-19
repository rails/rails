class RemoveNotNullOnActiveStorageBlobsChecksum < ActiveRecord::Migration[6.0]
  def change
    return unless table_exists?(ActiveStorage::VariantRecord.table_name)

    change_column_null(ActiveStorage::VariantRecord.table_name, :checksum, true)
  end
end
