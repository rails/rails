# frozen_string_literal: true

require_relative "../../../tools/strict_warnings"

ENV["RAILS_ENV"] ||= "test"
ENV["MULTI_DB"] = "true"

require "bundler/setup"
require "active_support"
require "active_support/test_case"
require "active_support/core_ext/object/try"
require "active_support/testing/autorun"
require "image_processing/mini_magick"
require "active_support/configuration_file"


require "active_record/testing/query_assertions"

require "active_job"
require_relative "../dummy/config/environment"

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
    {main: [ActiveStorage::MainBlob, MainRecord], animals: [ActiveStorage::AnimalsBlob, AnimalsRecord]}.each do |db_name, (blob_class, record_class)|
      define_method("create_#{db_name}_blob") do |key: nil, data: "Hello world!", filename: "hello.txt", content_type: "text/plain", identify: true, service_name: nil, record: nil|
        blob_class.create_and_upload! key: key, io: StringIO.new(data), filename: filename, content_type: content_type, identify: identify, service_name: service_name, record: record
      end

      define_method("create_#{db_name}_file_blob") do |key: nil, filename: "racecar.jpg", fixture: filename, content_type: "image/jpeg", identify: true, metadata: nil, service_name: nil, record: nil|
        blob_class.create_and_upload! io: file_fixture(fixture).open, filename: filename, content_type: content_type, identify: identify, metadata: metadata, service_name: service_name, record: record
      end

      define_method("create_#{db_name}_blob_before_direct_upload") do |key: nil, filename: "hello.txt", byte_size:, checksum:, content_type: "text/plain", record: nil|
        blob_class.create_before_direct_upload! key: key, filename: filename, byte_size: byte_size, checksum: checksum, content_type: content_type, record: record
      end

      define_method("build_#{db_name}_blob_after_unfurling") do |key: nil, data: "Hello world!", filename: "hello.txt", content_type: "text/plain", identify: true, record: nil|
        blob_class.build_after_unfurling key: key, io: StringIO.new(data), filename: filename, content_type: content_type, identify: identify, record: record
      end

      define_method("directly_upload_#{db_name}_file_blob") do |filename: "racecar.jpg", content_type: "image/jpeg", record: nil|
        file = file_fixture(filename)
        byte_size = file.size
        checksum = ActiveStorage.checksum_implementation.file(file).base64digest

        send("create_#{db_name}_blob_before_direct_upload", filename: filename, byte_size: byte_size, checksum: checksum, content_type: content_type, record: record).tap do |blob|
          service = blob_class.service.try(:primary) || blob_class.service
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

      def without_variant_tracking(&block)
        variant_tracking_was = ActiveStorage.track_variants
        ActiveStorage.track_variants = false
        yield
      ensure
        ActiveStorage.track_variants = variant_tracking_was
      end
    end

    def with_main_service(service_name)
      previous_service = ActiveStorage::MainBlob.service
      ActiveStorage::MainBlob.service = service_name ? ActiveStorage::MainBlob.services.fetch(service_name) : nil

      yield
    ensure
      ActiveStorage::MainBlob.service = previous_service
    end

    def with_animals_service(service_name)
      previous_service = ActiveStorage::AnimalsBlob.service
      ActiveStorage::AnimalsBlob.service = service_name ? ActiveStorage::AnimalsBlob.services.fetch(service_name) : nil

      yield
    ensure
      ActiveStorage::AnimalsBlob.service = previous_service
    end

    def with_strict_loading_by_default(&block)
      strict_loading_was = ActiveRecord::Base.strict_loading_by_default
      ActiveRecord::Base.strict_loading_by_default = true
      yield
    ensure
      ActiveRecord::Base.strict_loading_by_default = strict_loading_was
    end

    def with_raise_on_open_redirects_main(&block)
      old_raise_on_open_redirects = ActionController::Base.raise_on_open_redirects
      old_service = ActiveStorage::MainBlob.service

      ActionController::Base.raise_on_open_redirects = true
      ActiveStorage::MainBlob.service = ActiveStorage::Service.configure(service, SERVICE_CONFIGURATIONS)
      yield
    ensure
      ActionController::Base.raise_on_open_redirects = old_raise_on_open_redirects
      ActiveStorage::MainBlob.service = old_service
    end

    def with_raise_on_open_redirects_animals(&block)
      old_raise_on_open_redirects = ActionController::Base.raise_on_open_redirects
      old_service = ActiveStorage::AnimalsBlob.service

      ActionController::Base.raise_on_open_redirects = true
      ActiveStorage::AnimalsBlob.service = ActiveStorage::Service.configure(service, SERVICE_CONFIGURATIONS)
      yield
    ensure
      ActionController::Base.raise_on_open_redirects = old_raise_on_open_redirects
      ActiveStorage::AnimalsBlob.service = old_service
    end
end

require "global_id"
GlobalID.app = "ActiveStorageExampleApp"
ActiveRecord::Base.include GlobalID::Identification

class MainUser < MainRecord
  self.table_name = "users"

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

class MainGroup < MainRecord
  self.table_name = "groups"

  has_one_attached :avatar
  has_many :users, autosave: true, class_name: "MainUser", foreign_key: "group_id"

  accepts_nested_attributes_for :users
end

class AnimalsUser < AnimalsRecord
  self.table_name = "users"

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

class AnimalsGroup < AnimalsRecord
  self.table_name = "groups"

  has_one_attached :avatar
  has_many :users, autosave: true, class_name: "AnimalsUser", foreign_key: "group_id"

  accepts_nested_attributes_for :users
end

require_relative "../../../tools/test_common"
