# frozen_string_literal: true

# Provides asynchronous analysis of ActiveStorage::Blob records via ActiveStorage::Blob#analyze_later.
class ActiveStorage::AnalyzeJob < ActiveStorage::BaseJob
  retry_on ActiveStorage::IntegrityError, attempts: 10, wait: :exponentially_longer

  def perform(blob)
    blob.analyze
  end
end
