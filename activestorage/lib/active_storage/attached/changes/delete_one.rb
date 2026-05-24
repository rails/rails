# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::DeleteOne # :nodoc:
    include ActiveStorage::Attached::Changes::OwnerDispatch

    attr_reader :name
    attr_accessor :record

    def initialize(name, record)
      @name, @record = name, record
    end

    def attachment
      nil
    end

    def analyze
      # Nothing to analyze when deleting
    end

    def save
      if ar_owner?
        record.public_send("#{name}_attachment=", nil)
      else
        reset_deferred_purges

        begin
          attachment_class.transaction do
            attachment_class
              .where(record_type: polymorphic_owner_type, record_id: record.id, name: name)
              .each { |attachment| collect_deferred_purge(attachment) }
          end

          record.public_send("#{name}_attachment=", nil)
          record.public_send("#{name}_blob=", nil)
        rescue StandardError
          reset_deferred_purges
          raise
        end
      end
    end
  end
end
