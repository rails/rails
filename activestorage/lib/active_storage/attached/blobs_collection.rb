# frozen_string_literal: true

class ActiveStorage::Attached::BlobsCollection # :nodoc:
  include ActiveStorage::Attached::EnumerableCollection

  delegate :each, :to_a, :size, :count, :empty?, :first, :last,
    :include?, :as_json, :+, :map, :select, :reject, to: :blobs
  delegate_missing_to :to_a

  def initialize(record, name)
    @attachments_collection = ActiveStorage::Attached::Collection.new(record, name)
  end

  def reload
    @blobs = nil
    @attachments_collection.reload
    self
  end

  private
    def blobs
      @blobs ||= @attachments_collection.to_a.filter_map(&:blob)
    end

    def query_unsupported_message(method)
      "#{method} chaining is not supported on Attached::BlobsCollection for non-ActiveRecord owners. " \
        "To run ad-hoc queries, call `#{ActiveStorage.blob_class.name}.where(...)` directly on your blob class."
    end
end
