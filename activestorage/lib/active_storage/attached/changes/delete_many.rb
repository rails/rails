# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::DeleteMany #:nodoc:
    attr_reader :name, :record

    def initialize(name, record)
      @name, @record = name, record
    end

    def attachments
      ActiveStorage.attachment_class.none
    end

    def blobs
      ActiveStorage.blob_class.none
    end

    def save
      record.public_send("#{name}_attachments=", [])
    end
  end
end
