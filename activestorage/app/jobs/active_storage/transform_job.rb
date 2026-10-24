# frozen_string_literal: true

class ActiveStorage::TransformJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:transform] }

  discard_on ActiveRecord::RecordNotFound, ActiveJob::DeserializationError::RecordNotFound
  retry_on ActiveStorage::IntegrityError, attempts: 10, wait: :polynomially_longer

  def perform(blob, transformations)
    blob.representation(declared_transformations(blob, transformations)).processed
  end

  private
    # Queues backed by jsonb reorder hash keys, which would change the variant's digest.
    def declared_transformations(blob, transformations)
      blob.attachments.each do |attachment|
        reflection = attachment.record_type.safe_constantize.try(:reflect_on_attachment, attachment.name)
        next unless reflection.respond_to?(:named_variants)

        reflection.named_variants.each_value do |named_variant|
          return named_variant.transformations if named_variant.transformations == transformations
        end
      end

      transformations
    end
end
