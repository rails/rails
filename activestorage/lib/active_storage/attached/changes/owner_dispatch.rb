# frozen_string_literal: true

module ActiveStorage::Attached::Changes::OwnerDispatch # :nodoc:
  def deferred_purges
    @deferred_purges ||= []
  end

  def reset_deferred_purges
    @deferred_purges = []
  end

  def collect_deferred_purge(attachment)
    if deferred_purge = ActiveStorage::Attached::Changes.destroy_attachment(record, name, attachment)
      deferred_purges << deferred_purge
    end
  end

  def flush_deferred_purges
    ActiveStorage::Attached::Changes.flush_pending_purges(deferred_purges)
  ensure
    reset_deferred_purges
  end

  private
    def attachment_class
      ar_owner? ? ::ActiveStorage::Attachment : ActiveStorage.attachment_class
    end

    def blob_class
      ar_owner? ? ::ActiveStorage::Blob : ActiveStorage.blob_class
    end

    def ar_owner?
      defined?(::ActiveRecord::Base) && record.is_a?(::ActiveRecord::Base)
    end

    def polymorphic_owner_type
      ActiveStorage::Attached::Changes.polymorphic_name(record)
    end
end
