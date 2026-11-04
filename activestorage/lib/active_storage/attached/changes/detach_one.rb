# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::DetachOne # :nodoc:
    attr_reader :name, :record, :attachment

    def initialize(name, record, attachment)
      @name, @record, @attachment = name, record, attachment
    end

    def detach
      if attachment.present?
        attachment.delete
        reset
      end
    end

    private
      def reset
        record.attachment_changes.delete(name)
        record.public_send("#{name}_attachment=", nil)
      end
  end
end
