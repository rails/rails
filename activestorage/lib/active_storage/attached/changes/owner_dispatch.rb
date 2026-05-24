# frozen_string_literal: true

# :markup: markdown

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

  private
    def reset_attachment
      record.attachment_changes.delete(name)
      record.public_send("#{name}_attachment=", nil)
      unless ar_owner?
        record.public_send("#{name}_blob=", nil)
        record.send(:prune_attachment_uploads)
      end
    end

    def cleanup_record_after_failed_save(record, label)
      record.destroy if record.persisted? && record.respond_to?(:destroy)
    rescue StandardError => error
      # Don't shadow the original attachment save failure.
      ActiveStorage.logger&.warn(
        "[ActiveStorage] Failed to clean up #{label} after attachment save failed: #{error.class}: #{error.message}"
      )
    end

    def attachment_class
      ar_owner? ? ::ActiveStorage::Attachment : ActiveStorage.attachment_class
    end

    def blob_class
      ar_owner? ? ::ActiveStorage::Blob : ActiveStorage.blob_class
    end

    def ar_owner?
      ActiveStorage::Attached::Builder.active_record_owner?(record.class)
    end

    def polymorphic_owner_type
      ActiveStorage::Attached::Changes.polymorphic_name(record)
    end
end
