# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::PurgeMany # :nodoc:
    attr_reader :name, :record, :attachments

    def initialize(name, record, attachments)
      @name, @record, @attachments = name, record, attachments
    end

    def purge
      attachments.each(&:purge)
      reset
    end

    def purge_later
      attachments.each(&:purge_later)
      reset
    end

    private
      def reset
        record.attachment_changes.delete(name)
        record.public_send("#{name}_attachments").reset
      end
  end
end
