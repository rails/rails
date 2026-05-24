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

    attr_reader :name, :record

    def initialize(name, record)
      @name, @record = name, record
    end

    private
      def change
        record.attachment_changes[name]
      end
  end
end

require "active_storage/attached/model"
require "active_storage/attached/one"
require "active_storage/attached/many"
require "active_storage/attached/changes"
