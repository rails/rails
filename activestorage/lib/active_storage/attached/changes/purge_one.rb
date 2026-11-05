# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::PurgeOne # :nodoc:
    attr_reader :name, :record, :attachment

    def initialize(name, record, attachment)
      @name, @record, @attachment = name, record, attachment
    end

    def purge
      attachment&.purge
      reset
    end

    def purge_later
      attachment&.purge_later
      reset
    end

    private
      def reset
        record.attachment_changes.delete(name)
        record.public_send("#{name}_attachment=", nil)
      end
  end
end
