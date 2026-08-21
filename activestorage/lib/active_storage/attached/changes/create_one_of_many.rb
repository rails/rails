# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::CreateOneOfMany < Attached::Changes::CreateOne # :nodoc:
    def initialize(name, record, attachable, attachments_by_blob)
      @attachments_by_blob = attachments_by_blob
      super(name, record, attachable)
    end

    private
      def find_attachment
        if blob.persisted?
          @attachments_by_blob[blob.id]
        else
          blob.attachments.find { |attachment| attachment.record == record }
        end
      end
  end
end
