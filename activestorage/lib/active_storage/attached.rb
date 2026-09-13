# frozen_string_literal: true

module ActiveStorage
  # = Active Storage \Attached
  #
  # Abstract base class for the concrete ActiveStorage::Attached::One and ActiveStorage::Attached::Many
  # classes that both provide proxy access to the blob association for a record.
  class Attached
    autoload :Builder, "active_storage/attached/builder"
    autoload :Collection, "active_storage/attached/collection"
    autoload :BlobsCollection, "active_storage/attached/blobs_collection"
    autoload :EnumerableCollection, "active_storage/attached/enumerable_collection"

    attr_reader :name, :record

    def initialize(name, record)
      @name, @record = name, record
    end

    private
      def change
        record.attachment_changes[name]
      end

      def record_changed?
        record.respond_to?(:changed?) && record.changed?
      end

      def record_not_saved_error
        if defined?(::ActiveRecord::Base) && record.is_a?(::ActiveRecord::Base)
          ::ActiveRecord::RecordNotSaved
        else
          ActiveStorage::RecordNotSaved
        end
      end
  end
end

require "active_storage/attached/model"
require "active_storage/attached/one"
require "active_storage/attached/many"
require "active_storage/attached/changes"
