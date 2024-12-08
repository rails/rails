class CreateActiveStorageVariantRecords < ActiveRecord::Migration[6.0]
  def change
    return unless table_exists?(ActiveStorage::Blob.table_name)

    # Use Active Record's configured type for primary key
    create_table ActiveStorage::VariantRecord.table_name, id: primary_key_type, if_not_exists: true do |t|
      t.belongs_to :blob, null: false, index: false, type: blobs_primary_key_type
      t.string :variation_digest, null: false

      t.index %i[ blob_id variation_digest ], name: "index_#{ActiveStorage::VariantRecord.table_name}_uniqueness", unique: true
      t.foreign_key ActiveStorage::VariantRecord.table_name, column: :blob_id
    end
  end

  private
    def primary_key_type
      config = Rails.configuration.generators
      config.options[config.orm][:primary_key_type] || :primary_key
    end

    def blobs_primary_key_type
      pkey_name = connection.primary_key(ActiveStorage::VariantRecord.table_name)
      pkey_column = connection.columns(ActiveStorage::VariantRecord.table_name).find { |c| c.name == pkey_name }
      pkey_column.bigint? ? :bigint : pkey_column.type
    end
end
