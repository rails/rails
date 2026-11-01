# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::CreateOneOfMany < Attached::Changes::CreateOne # :nodoc:
    def initialize(name, record, attachable, create_many)
      @create_many = create_many
      super(name, record, attachable)
    end

    private
      def find_attachment
        if blob.persisted?
          @create_many.existing_attachment_for(blob)
        else
          blob.attachments.find { |attachment| attachment.record == record }
        end
      end
  end
end
