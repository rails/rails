# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

# = Active Storage \Attachment
#
# Attachments associate records with blobs. Usually that's a one record-many blobs relationship,
# but it is possible to associate many different records with the same blob. A foreign-key constraint
# on the attachments table prevents blobs from being purged if they’re still attached to any records.
#
# Attachments also have access to all methods from ActiveStorage::Blob.
#
# If you wish to preload attachments or blobs, you can use these scopes:
#
#   # preloads attachments, their corresponding blobs, and variant records (if using `ActiveStorage.track_variants`)
#   User.all.with_attached_avatars
#
#   # preloads blobs and variant records (if using `ActiveStorage.track_variants`)
#   User.first.avatars.with_all_variant_records
class ActiveStorage::Attachment < ActiveStorage::Record
  ##
  # :method:
  #
  # Returns the associated record.
  belongs_to :record, polymorphic: true, touch: true

  ##
  # :method:
  #
  # Returns the associated ActiveStorage::Blob.
  belongs_to :blob, class_name: "ActiveStorage::Blob", autosave: true

  delegate_missing_to :blob
  delegate :signed_id, to: :blob

  after_create_commit :mirror_blob_later, :analyze_blob_later, :transform_variants_later
  after_destroy_commit :purge_dependent_blob_later

  ##
  # :singleton-method:
  #
  # Eager load all variant records on an attachment at once.
  #
  #   User.first.avatars.with_all_variant_records
  scope :with_all_variant_records, -> { includes(blob: {
    variant_records: { image_attachment: :blob },
    preview_image_attachment: { blob: { variant_records: { image_attachment: :blob } } }
  }) }

  # Synchronously deletes the attachment and {purges the blob}[rdoc-ref:ActiveStorage::Blob#purge].
  def purge
    transaction do
      delete
      record.touch if record&.persisted?
    end
    blob&.purge
  end

  # Deletes the attachment and {enqueues a background job}[rdoc-ref:ActiveStorage::Blob#purge_later] to purge the blob.
  def purge_later
    transaction do
      delete
      record.touch if record&.persisted?
    end
    blob&.purge_later
  end

  # Returns an ActiveStorage::Variant or ActiveStorage::VariantWithRecord
  # instance for the attachment with the set of +transformations+ provided.
  # Example:
  #
  #   avatar.variant(resize_to_limit: [100, 100]).processed.url
  #
  # or if you are using pre-defined variants:
  #
  #   avatar.variant(:thumb).processed.url
  #
  # See ActiveStorage::Blob::Representable#variant for more information.
  #
  # Raises an +ArgumentError+ if +transformations+ is a +Symbol+ which is an
  # unknown pre-defined variant of the attachment.
  def variant(transformations)
    transformations = transformations_by_name(transformations)
    blob.variant(transformations)
  end

  # Returns an ActiveStorage::Preview instance for the attachment with the set
  # of +transformations+ provided.
  # Example:
  #
  #   video.preview(resize_to_limit: [100, 100]).processed.url
  #
  # or if you are using pre-defined variants:
  #
  #   video.preview(:thumb).processed.url
  #
  # See ActiveStorage::Blob::Representable#preview for more information.
  #
  # Raises an +ArgumentError+ if +transformations+ is a +Symbol+ which is an
  # unknown pre-defined variant of the attachment.
  def preview(transformations)
    transformations = transformations_by_name(transformations)
    blob.preview(transformations)
  end

  # Returns an ActiveStorage::Preview or an ActiveStorage::Variant for the
  # attachment with set of +transformations+ provided.
  # Example:
  #
  #   avatar.representation(resize_to_limit: [100, 100]).processed.url
  #
  # or if you are using pre-defined variants:
  #
  #   avatar.representation(:thumb).processed.url
  #
  # See ActiveStorage::Blob::Representable#representation for more information.
  #
  # Raises an +ArgumentError+ if +transformations+ is a +Symbol+ which is an
  # unknown pre-defined variant of the attachment.
  def representation(transformations)
    transformations = transformations_by_name(transformations)
    blob.representation(transformations)
  end

  private
    def analyze_blob_later
      blob.analyze_later unless blob.analyzed?
    end

    def mirror_blob_later
      blob.mirror_later
    end

    def transform_variants_later
      preprocessed_variations = named_variants.filter_map { |_name, named_variant|
        if named_variant.preprocessed?(record)
          named_variant.transformations
        end
      }

      if blob.preview_image_needed_before_processing_variants?
        blob.create_preview_image_later(preprocessed_variations)
      else
        preprocessed_variations.each do |transformations|
          blob.preprocessed(transformations)
        end
      end
    end

    def purge_dependent_blob_later
      blob&.purge_later if dependent == :purge_later
    end

    def dependent
      record.attachment_reflections[name]&.options&.fetch(:dependent, nil)
    end

    def named_variants
      record.attachment_reflections[name]&.named_variants
    end

    def transformations_by_name(transformations)
      case transformations
      when Symbol
        variant_name = transformations
        named_variants.fetch(variant_name) do
          record_model_name = record.to_model.model_name.name
          raise ArgumentError, "Cannot find variant :#{variant_name} for #{record_model_name}##{name}"
        end.transformations
      else
        transformations
      end
    end
end

ActiveSupport.run_load_hooks :active_storage_attachment, ActiveStorage::Attachment
