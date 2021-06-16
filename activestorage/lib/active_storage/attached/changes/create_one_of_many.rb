# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::CreateOneOfMany < Attached::Changes::CreateOne #:nodoc:
    attr_reader :attachments

    def initialize(name, record, attachable, attachments)
      super(name, record, attachable)
      @attachments = attachments
    end

    private
      def find_attachment
        attachments.detect { |attachment| attachment.blob_id == blob.id }
      end
  end
end
