# frozen_string_literal: true

module ActiveStorage::Models::VariantRecord
  extend ActiveSupport::Concern

  included do
    belongs_to :blob, class_name: blob_class_name, foreign_key: :blob_id
    has_one_attached :image
  end
end

