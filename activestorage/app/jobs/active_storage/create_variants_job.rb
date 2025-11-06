# frozen_string_literal: true

class ActiveStorage::CreateVariantsJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:transform] }

  discard_on ActiveRecord::RecordNotFound
  retry_on ActiveStorage::IntegrityError, attempts: 10, wait: :polynomially_longer

  def perform(blob, variants:, process:)
    @blob = blob
    @process = process

    create_preview_image if preview_image_needed?

    variants.each do |transformations|
      ActiveStorage::TransformJob.public_send(perform_method, @blob, transformations)
    end
  end

  private
    def create_preview_image
      @blob.preview({}).processed
    end

    def preview_image_needed?
      @blob.previewable? && !@blob.preview_image.attached?
    end

    def perform_method
      (@process == :immediately) ? :perform_now : :perform_later
    end
end
