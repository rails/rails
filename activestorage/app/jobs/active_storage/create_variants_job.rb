# frozen_string_literal: true

class ActiveStorage::CreateVariantsJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:transform] }

  discard_on ActiveRecord::RecordNotFound
  retry_on ActiveStorage::IntegrityError, attempts: 10, wait: :polynomially_longer

  def perform(blob, transformations:, generate:)
    @blob = blob
    @generate = generate

    @blob.preview({}).processed if preview_image_needed?

    transformations.each do |transformation|
      ActiveStorage::TransformJob.public_send(perform_method, @blob, transformation)
    end
  end

  private
    def perform_method
      (@generate == :immediate) ? :perform_now : :perform_later
    end

    def preview_image_needed?
      @blob.previewable? && !@blob.preview_image.attached?
    end
end
