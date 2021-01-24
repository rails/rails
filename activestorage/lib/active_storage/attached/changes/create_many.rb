# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::CreateMany #:nodoc:
    attr_reader :name, :record, :attachables, :key

    def initialize(name, record, attachables, key)
      @name, @record, @attachables, @key = name, record, Array(attachables), key
      blobs.each(&:identify_without_saving)
    end

    def attachments
      @attachments ||= subchanges.collect(&:attachment)
    end

    def blobs
      @blobs ||= subchanges.collect(&:blob)
    end

    def upload
      subchanges.each(&:upload)
    end

    def save
      assign_associated_attachments
      reset_associated_blobs
    end

    private
      def subchanges
        @subchanges ||= attachables.collect { |attachable| build_subchange_from(attachable) }
      end

      def build_subchange_from(attachable)
        ActiveStorage::Attached::Changes::CreateOneOfMany.new(name, record, attachable, key)
      end


      def assign_associated_attachments
        record.public_send("#{name}_attachments=", attachments)
      end

      def reset_associated_blobs
        record.public_send("#{name}_blobs").reset
      end
  end
end
