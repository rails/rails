# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::DetachMany # :nodoc:
    include ActiveStorage::Attached::Changes::OwnerDispatch

    attr_reader :name, :record, :attachments

    def initialize(name, record, attachments)
      @name, @record, @attachments = name, record, attachments
    end

    def detach
      if attachments.any?
        attachments.delete_all if attachments.respond_to?(:delete_all)
        record.attachment_changes.delete(name)
        record.public_send("#{name}_attachments").reset if record.public_send("#{name}_attachments").respond_to?(:reset)
        record.public_send("#{name}_blobs").reset if record.public_send("#{name}_blobs").respond_to?(:reset)
      end
    end
  end
end
