# frozen_string_literal: true

class ActiveStorage::VariantRecord < ActiveStorage::Record
  belongs_to :blob
  has_one_attached :image
end

ActiveSupport.run_load_hooks :active_storage_variant_record, ActiveStorage::VariantRecord
