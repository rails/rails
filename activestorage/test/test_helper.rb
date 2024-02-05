# frozen_string_literal: true

require "active_support/testing/strict_warnings"

ENV["RAILS_ENV"] ||= "test"

require "bundler/setup"
require "active_support"
require "active_support/test_case"
require "active_support/core_ext/object/try"
require "active_support/testing/autorun"
require "image_processing/mini_magick"

require "active_record/testing/query_assertions"

require "rails"
require "active_record/railtie"
require "active_storage/engine"

SERVICE_CONFIGURATIONS = begin
  ActiveSupport::ConfigurationFile.parse(File.expand_path("service/configurations.yml", __dir__)).deep_symbolize_keys
rescue Errno::ENOENT
  puts "Missing service configuration file in test/service/configurations.yml"
  {}
end
# Azure service tests are currently failing on the main branch.
# We temporarily disable them while we get things working again.
if ENV["BUILDKITE"]
  SERVICE_CONFIGURATIONS.delete(:azure)
  SERVICE_CONFIGURATIONS.delete(:azure_public)
end

module ActiveStorage
  class TestApp < Rails::Application
    config.eager_load = ENV["CI"].present?
    config.load_defaults Rails::VERSION::STRING.to_f
    config.secret_key_base = "secret_key_base"
    config.root = File.join(__dir__, "support")
    config.fixture_paths = [File.expand_path("fixtures", __dir__)]
    config.action_controller.allow_forgery_protection = false

    # Disable logging
    config.logger = Logger.new(nil)

    config.active_storage.service = :local

    config.active_storage.service_configurations = SERVICE_CONFIGURATIONS.merge(
      "local" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests") },
      "local_public" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests"), "public" => true },
      "disk_mirror_1" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests_1") },
      "disk_mirror_2" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests_2") },
      "disk_mirror_3" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests_3") },
      "mirror" => { "service" => "Mirror", "primary" => "local", "mirrors" => ["disk_mirror_1", "disk_mirror_2", "disk_mirror_3"] }
    ).deep_stringify_keys
  end
end

Rails.application.initialize!

require "active_job"
ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = ActiveSupport::Logger.new(nil)

ActiveStorage.logger = ActiveSupport::Logger.new(nil)
ActiveStorage.verifier = ActiveSupport::MessageVerifier.new("Testing")

class ActiveSupport::TestCase
  ActiveStorage::FixtureSet.file_fixture_path = File.expand_path("fixtures/files", __dir__)
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

    def create_file_blob(key: nil, filename: "racecar.jpg", content_type: "image/jpeg", metadata: nil, service_name: nil, record: nil)
      ActiveStorage::Blob.create_and_upload! io: file_fixture(filename).open, filename: filename, content_type: content_type, metadata: metadata, service_name: service_name, record: record
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
      checksum = OpenSSL::Digest::MD5.file(file).base64digest

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

    def subscribe_events_from(name)
      events = []
      ActiveSupport::Notifications.subscribe(name) { |event| events << event }
      events
    end
end

require "global_id"
GlobalID.app = "ActiveStorageExampleApp"
ActiveRecord::Base.include GlobalID::Identification

class User < ActiveRecord::Base
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

  accepts_nested_attributes_for :highlights_attachments, allow_destroy: true

  def should_preprocessed?
    name == "transform via method"
  end
end

class Group < ActiveRecord::Base
  has_one_attached :avatar
  has_many :users, autosave: true

  accepts_nested_attributes_for :users
end

require_relative "../../tools/test_common"
