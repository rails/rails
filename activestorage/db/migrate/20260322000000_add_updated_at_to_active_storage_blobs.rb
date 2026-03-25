# frozen_string_literal: true

class AddUpdatedAtToActiveStorageBlobs < ActiveRecord::Migration[8.1]
  def change
    add_column :active_storage_blobs, :updated_at, :datetime, precision: 6
  end
end
