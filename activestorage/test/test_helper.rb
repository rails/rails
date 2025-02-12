# frozen_string_literal: true

require "active_support/testing/strict_warnings"

ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment.rb"

require "bundler/setup"
require "active_support"
require "active_support/test_case"
require "active_support/core_ext/object/try"
require "active_support/testing/autorun"
require "image_processing/mini_magick"

require "active_record/testing/query_assertions"

require "active_job"
ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = ActiveSupport::Logger.new(nil)

ActiveStorage.logger = ActiveSupport::Logger.new(nil)
ActiveStorage.verifier = ActiveSupport::MessageVerifier.new("Testing")
ActiveStorage::FixtureSet.file_fixture_path = File.expand_path("fixtures/files", __dir__)

class ActiveSupport::TestCase
  self.file_fixture_path = ActiveStorage::FixtureSet.file_fixture_path

  include ActiveRecord::TestFixtures
  include ActiveRecord::Assertions::QueryAssertions

  self.fixture_paths = [File.expand_path("fixtures", __dir__)]

  setup do
    ActiveStorage::Current.url_options = { protocol: "https://", host: "example.com", port: nil }
  end

  teardown do
    ActiveStorage::Current.reset
  end

  private
    def create_blob(key: nil, data: "Hello world!", filename: "hello.txt", content_type: "text/plain", identify: true, service_name: nil, record: nil)
      ActiveStorage::Blob.create_and_upload! key: key, io: StringIO.new(data), filename: filename, content_type: content_type, identify: identify, service_name: service_name, record: record
    end

    def create_file_blob(key: nil, filename: "racecar.jpg", fixture: filename, content_type: "image/jpeg", identify: true, metadata: nil, service_name: nil, record: nil)
      ActiveStorage::Blob.create_and_upload! io: file_fixture(fixture).open, filename: filename, content_type: content_type, identify: identify, metadata: metadata, service_name: service_name, record: record
    end

    def create_blob_before_direct_upload(key: nil, filename: "hello.txt", byte_size:, checksum:, content_type: "text/plain", record: nil)
      ActiveStorage::Blob.create_before_direct_upload! key: key, filename: filename, byte_size: byte_size, checksum: checksum, content_type: content_type, record: record
    end

    def build_blob_after_unfurling(key: nil, data: "Hello world!", filename: "hello.txt", content_type: "text/plain", identify: true, record: nil)
      ActiveStorage::Blob.build_after_unfurling key: key, io: StringIO.new(data), filename: filename, content_type: content_type, identify: identify, record: record
    end

    def directly_upload_file_blob(filename: "racecar.jpg", content_type: "image/jpeg", record: nil)
      file = file_fixture(filename)
      byte_size = file.size
      checksum = ActiveStorage.checksum_implementation.file(file).base64digest

      create_blob_before_direct_upload(filename: filename, byte_size: byte_size, checksum: checksum, content_type: content_type, record: record).tap do |blob|
        service = ActiveStorage::Blob.service.try(:primary) || ActiveStorage::Blob.service
        service.upload(blob.key, file.open)
      end
    end

    def read_image(blob_or_variant)
      MiniMagick::Image.open blob_or_variant.service.send(:path_for, blob_or_variant.key)
    end

    def extract_metadata_from(blob)
      blob.tap(&:analyze).metadata
    end

    def fixture_file_upload(filename)
      Rack::Test::UploadedFile.new file_fixture(filename).to_s
    end

    def with_service(service_name)
      previous_service = ActiveStorage::Blob.service
      ActiveStorage::Blob.service = service_name ? ActiveStorage::Blob.services.fetch(service_name) : nil

      yield
    ensure
      ActiveStorage::Blob.service = previous_service
    end

    def with_strict_loading_by_default(&block)
      strict_loading_was = ActiveRecord::Base.strict_loading_by_default
      ActiveRecord::Base.strict_loading_by_default = true
      yield
    ensure
      ActiveRecord::Base.strict_loading_by_default = strict_loading_was
    end

    def without_variant_tracking(&block)
      variant_tracking_was = ActiveStorage.track_variants
      ActiveStorage.track_variants = false
      yield
    ensure
      ActiveStorage.track_variants = variant_tracking_was
    end

    def with_raise_on_open_redirects(service)
      old_raise_on_open_redirects = ActionController::Base.raise_on_open_redirects
      old_service = ActiveStorage::Blob.service

      ActionController::Base.raise_on_open_redirects = true
      ActiveStorage::Blob.service = ActiveStorage::Service.configure(service, SERVICE_CONFIGURATIONS)
      yield
    ensure
      ActionController::Base.raise_on_open_redirects = old_raise_on_open_redirects
      ActiveStorage::Blob.service = old_service
    end
end

require "global_id"
GlobalID.app = "ActiveStorageExampleApp"
ActiveRecord::Base.include GlobalID::Identification

class User < ActiveRecord::Base
  attr_accessor :record_callbacks, :callback_counter
  attr_reader :notification_sent

  validates :name, presence: true

  has_one_attached :avatar
  has_one_attached :cover_photo, dependent: false, service: :local
  has_one_attached :avatar_with_variants do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
  end
  has_one_attached :avatar_with_preprocessed do |attachable|
    attachable.variant :bool, resize_to_limit: [1, 1], preprocessed: true
  end
  has_one_attached :avatar_with_conditional_preprocessed do |attachable|
    attachable.variant :proc, resize_to_limit: [2, 2],
      preprocessed: ->(user) { user.name == "transform via proc" }
    attachable.variant :method, resize_to_limit: [3, 3],
      preprocessed: :should_preprocessed?
  end
  has_one_attached :intro_video
  has_one_attached :name_pronunciation_audio

  has_many_attached :highlights
  has_many_attached :vlogs, dependent: false, service: :local
  has_many_attached :highlights_with_variants do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
  end
  has_many_attached :highlights_with_preprocessed do |attachable|
    attachable.variant :bool, resize_to_limit: [1, 1], preprocessed: true
  end
  has_many_attached :highlights_with_conditional_preprocessed do |attachable|
    attachable.variant :proc, resize_to_limit: [2, 2],
      preprocessed: ->(user) { user.name == "transform via proc" }
    attachable.variant :method, resize_to_limit: [3, 3],
      preprocessed: :should_preprocessed?
  end
  has_one_attached :resume do |attachable|
    attachable.variant :preview, resize_to_fill: [400, 400]
  end
  has_one_attached :resume_with_preprocessing do |attachable|
    attachable.variant :preview, resize_to_fill: [400, 400], preprocessed: true
  end

  after_commit :increment_callback_counter
  after_update_commit :notify

  accepts_nested_attributes_for :highlights_attachments, allow_destroy: true

  def should_preprocessed?
    name == "transform via method"
  end

  def increment_callback_counter
    if record_callbacks
      @callback_counter ||= 0
      @callback_counter += 1
    end
  end

  def notify
    @notification_sent = true if highlights_attachments.any?(&:previously_new_record?)
  end
end

class Group < ActiveRecord::Base
  has_one_attached :avatar
  has_many :users, autosave: true

  accepts_nested_attributes_for :users
end

require_relative "../../tools/test_common"
