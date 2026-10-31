# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::DetachMany # :nodoc:
    attr_reader :name, :record, :attachments

    def initialize(name, record, attachments)
      @name, @record, @attachments = name, record, attachments
    end

    def detach
      if attachments.any?
        attachments.delete_all if attachments.respond_to?(:delete_all)
        record.attachment_changes.delete(name)
      end
    end
  end
end
