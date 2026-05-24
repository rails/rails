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
        if attachments.respond_to?(:delete_all)
          attachments.delete_all
        elsif !ar_owner?
          attachments.each(&:delete)
        end
        record.attachment_changes.delete(name)
        unless ar_owner?
          record.public_send("#{name}_attachments").reset if record.public_send("#{name}_attachments").respond_to?(:reset)
          record.public_send("#{name}_blobs").reset if record.public_send("#{name}_blobs").respond_to?(:reset)
          record.send(:prune_attachment_uploads)
        end
      end
    end
  end
end
