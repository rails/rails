# frozen_string_literal: true

module ActiveStorage
  module Attached::Changes # :nodoc:
    extend ActiveSupport::Autoload

    autoload :OwnerDispatch, "active_storage/attached/changes/owner_dispatch"

    DeferredPurge = Struct.new(:blob, :strategy)

    def self.destroy_attachment(record, name, attachment)
      dependent = dependent_option(record, name)
      blob = attachment.blob if dependent == :purge || dependent == :purge_later

      unless attachment.destroy
        raise ActiveStorage::RecordNotDestroyed.new("Failed to destroy attachment", attachment)
      end

      case dependent
      when :purge, :purge_later
        DeferredPurge.new(blob, dependent)
      end
    end

    def self.flush_pending_purges(purges)
      # Purge each blob at most once: the same blob can be attached under several
      # names, so a destroy may collect more than one deferred purge for it.
      # A synchronous +:purge+ takes precedence over +:purge_later+.
      by_blob = {}
      Array(purges).compact.each do |purge|
        next unless purge.blob

        existing = by_blob[purge.blob.id]
        if existing.nil? || (existing.strategy == :purge_later && purge.strategy == :purge)
          by_blob[purge.blob.id] = purge
        end
      end

      by_blob.each_value do |purge|
        case purge.strategy
        when :purge
          purge.blob.purge
        when :purge_later
          purge.blob.purge_later
        end
      end
    end

    def self.polymorphic_name(record)
      record.class.respond_to?(:polymorphic_name) ? record.class.polymorphic_name : record.class.name
    end

    def self.dependent_option(record, name)
      record.class.attachment_reflections[name.to_s]&.options&.fetch(:dependent, nil)
    end

    eager_autoload do
      autoload :CreateOne
      autoload :CreateMany
      autoload :CreateOneOfMany

      autoload :DeleteOne
      autoload :DeleteMany

      autoload :DetachOne
      autoload :DetachMany

      autoload :PurgeOne
      autoload :PurgeMany
    end
  end
end
