# frozen_string_literal: true

class ActiveStorage::PreviewImageJob < ActiveStorage::BaseJob
  queue_as { ActiveStorage.queues[:preview_image] }

  discard_on ActiveRecord::RecordNotFound, ActiveStorage::UnrepresentableError
  retry_on ActiveStorage::IntegrityError, attempts: 10, wait: :polynomially_longer

  def initialize(*arguments)
    ActiveStorage.deprecator.warn(<<~MSG.squish)
      ActiveStorage::PreviewImageJob is no longer used by Rails.
      It is deprecated and will be removed in Rails 9.0.
      Use the ActiveStorage::CreateVariantsJob instead.
    MSG
    super
  end

  def perform(blob, variations)
    blob.preview({}).processed

    variations.each do |transformations|
      ActiveStorage::TransformJob.perform_later(blob, transformations) if blob.representable?
    end
  end
end
