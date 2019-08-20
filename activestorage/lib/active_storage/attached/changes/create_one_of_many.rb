# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::CreateOneOfMany < Attached::Changes::CreateOne #:nodoc:
    private
      def find_attachment
        record.public_send("#{name}_attachments").detect { |attachment| attachment.blob_id == blob.id }
      end
  end
end
