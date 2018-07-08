# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::CreateMany #:nodoc:
    attr_reader :name, :record, :attachables

    def initialize(name, record, attachables)
      @name, @record, @attachables = name, record, Array(attachables)
    end

    def attachments
      @attachments ||= subchanges.collect(&:attachment)
    end

    def upload
      subchanges.each(&:upload)
    end

    def save
      record.public_send("#{name}_attachments=", attachments)
    end

    private
      def subchanges
        @subchanges ||= attachables.collect { |attachable| build_subchange_from(attachable) }
      end

      def build_subchange_from(attachable)
        ActiveStorage::Attached::Changes::CreateOneOfMany.new(name, record, attachable)
      end
  end
end
