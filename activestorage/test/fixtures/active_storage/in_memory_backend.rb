# frozen_string_literal: true

require "active_model"
require "global_id"
require "marcel"
require "securerandom"
require File.expand_path("../../../app/models/active_storage/servable", __dir__)

require_relative "in_memory_backend/relation"
require_relative "in_memory_backend/store"
require_relative "in_memory_backend/blob"
require_relative "in_memory_backend/attachment"
require_relative "in_memory_backend/variant_record"

module ActiveStorage::InMemoryBackend
  def self.install
    return if @installed

    Blob.has_one_attached :preview_image
    VariantRecord.has_one_attached :image
    @installed = true
  end

  def self.reset
    Blob.reset
    Attachment.reset
    VariantRecord.reset
  end
end
