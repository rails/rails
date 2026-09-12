# frozen_string_literal: true

module ActiveStorage::InMemoryBackend
  class VariantRecord
    include Store
    include ActiveStorage::Attached::Model

    attr_accessor :blob_id, :variation_digest

    class << self
      def create_or_find_by!(attributes)
        find_by(attributes) || new(attributes).tap do |record|
          yield record if block_given?
          record.save!
        end
      end
    end
  end
end
