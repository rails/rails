# frozen_string_literal: true

# Provides asynchronous analysis of ActiveStorage::Blob records via ActiveStorage::Blob#analyze_later.
class ActiveStorage::AnalyzeJob < ActiveStorage::BaseJob
  def perform(blob)
    blob.analyze
  end
end
