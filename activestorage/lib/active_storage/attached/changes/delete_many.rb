# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::DeleteMany # :nodoc:
    attr_reader :name, :record

    def initialize(name, record)
      @name, @record = name, record
    end

    def attachables
      []
    end

    def attachments
      attachment_class.none
    end

    def blobs
      blob_class.none
    end

    def save
      record.public_send("#{name}_attachments=", [])
    end

    def attachment_class
      @attachment_class ||= ClassResolver.resolve(record.class, :attachment)
    end

    def blob_class
      ClassResolver.resolve(record.class, :blob)
    end
  end
end
