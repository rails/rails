# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::DeleteMany # :nodoc:
    attr_reader :name
    attr_accessor :record

    def initialize(name, record)
      @name, @record = name, record
    end

    def attachables
      []
    end

    def attachments
      ActiveStorage.attachment_class.none
    end

    def blobs
      ActiveStorage.blob_class.none
    end

    def analyze
      # Nothing to analyze when deleting
    end

    def save
      record.public_send("#{name}_attachments=", [])
    end
  end
end
