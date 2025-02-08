# frozen_string_literal: true

require "active_support/testing/strict_warnings"

require "bundler/setup"
require "active_support"
require "active_support/testing/autorun"

require "active_record/testing/query_assertions"

require "zeitwerk"
loader = Zeitwerk::Loader.new
loader.push_dir("app/controllers")
loader.push_dir("app/controllers/concerns")
loader.push_dir("app/jobs")
loader.push_dir("app/models")
loader.setup

require "action_view"
require "action_controller"

require "openssl"
require "active_storage"
require "active_storage/reflection"
require "active_storage/service/registry"

module Rails
  def self.application
    @app ||= Application.new
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.env
    "test"
  end

  class Application
    def config
      Rails.configuration
    end

    def env_config
      {}
    end

    def routes
      @routes ||= ActionDispatch::Routing::RouteSet.new
    end
  end

  class Configuration
    def active_storage
      @active_storage ||= ActiveSupport::OrderedOptions.new.tap do |config|
        config.service = :local
      end
    end

    def generators(&block)
      @generators ||= Generators.new
      yield @generators if block_given?
      @generators
    end
  end

  class Generators
    attr_accessor :options

    def initialize
      @options = { active_record: { primary_key_type: nil } }
      @orm = :active_record
    end

    def orm(orm = nil, options = {})
      if orm
        @options[orm] = options
      else
        @orm
      end
    end
  end
end

load "config/routes.rb"
Rails.application.routes.default_url_options = { host: "example.com" }

class RoutedRackApp
  attr_reader :routes

  def initialize(routes, &blk)
    @routes = routes
    @stack = ActionDispatch::MiddlewareStack.new(&blk)
    @app = @stack.build(@routes)
  end

  def call(env)
    @app.call(env)
  end
end

class ActionDispatch::IntegrationTest < ActiveSupport::TestCase
  def self.build_app
    RoutedRackApp.new(Rails.application.routes) do |middleware|
      yield(middleware) if block_given?
    end
  end

  self.app = build_app
end

ActionView::TestCase.include(Rails.application.routes.url_helpers)

ActiveRecord.include(ActiveStorage::Attached::Model)
ActiveRecord::Base.include(ActiveStorage::Attached::Model)

ActiveRecord::Base.include(ActiveStorage::Reflection::ActiveRecordExtensions)
ActiveRecord::Reflection.singleton_class.prepend(ActiveStorage::Reflection::ReflectionExtension)

ActiveSupport.on_load(:active_record) do
  ActiveStorage.singleton_class.redefine_method(:table_name_prefix) do
    "#{ActiveRecord::Base.table_name_prefix}active_storage_"
  end
end

SERVICE_CONFIGURATIONS = begin
  config_file = File.join(__dir__, "service/configurations.yml")
  ActiveSupport::ConfigurationFile.parse(config_file, symbolize_names: true)
rescue Errno::ENOENT
  puts "Missing service configuration file in #{config_file}"
  {}
end
# Azure service tests are currently failing on the main branch.
# We temporarily disable them while we get things working again.
if ENV["BUILDKITE"]
  SERVICE_CONFIGURATIONS.delete(:azure)
  SERVICE_CONFIGURATIONS.delete(:azure_public)
end

ActiveStorage::Blob.services = ActiveStorage::Service::Registry.new(SERVICE_CONFIGURATIONS.merge(
  "local" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests") },
  "local_public" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests"), "public" => true },
  "disk_mirror_1" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests_1") },
  "disk_mirror_2" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests_2") },
  "disk_mirror_3" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests_3") },
  "mirror" => { "service" => "Mirror", "primary" => "local", "mirrors" => ["disk_mirror_1", "disk_mirror_2", "disk_mirror_3"] }
).deep_stringify_keys)

ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch(:local)

ActiveStorage::Blob.service.class.redefine_method(:url_helpers) do
  @url_helpers ||= Rails.application.routes.url_helpers
end

class ActiveStorageCreateGroups < ActiveRecord::Migration[6.0]
  def change
    create_table :groups do |t|
    end
  end
end

class ActiveStorageCreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      t.string :name
      t.integer :group_id
      t.timestamps
    end
  end
end

# Writing and reading roles are required for the "previewing on the writer DB" test
ActiveRecord::Base.connects_to(database: { writing: "sqlite3::memory:", reading: "sqlite3::memory:" })
ActiveRecord::Base.connection_pool.migration_context.migrate

ActiveStorageCreateUsers.migrate(:up)
ActiveStorageCreateGroups.migrate(:up)

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
    @after_teardown_analyzers = ActiveStorage.analyzers
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

    def process_variants_with(processor)
      previous_transformer = ActiveStorage.variant_transformer
      ActiveStorage.variant_transformer =
        case processor
        when :vips
          ActiveStorage::Transformers::Vips
        when :mini_magick
          ActiveStorage::Transformers::ImageMagick
        else
          raise "#{processor.inspect} is not a valid image transformer"
        end

      yield
    rescue LoadError
      ENV["BUILDKITE"] ? raise : skip("Variant processor #{processor.inspect} is not installed")
    ensure
      ActiveStorage.variant_transformer = previous_transformer
    end

    def analyze_with(*analyzers)
      previous_analyzers = ActiveStorage.analyzers
      ActiveStorage.analyzers = analyzers.map do |analyzer|
        ActiveStorage::Analyzer.const_get(analyzer)
      end
      yield
    ensure
      ActiveStorage.analyzers = previous_analyzers
    end

    def preview_with(*previewers)
      previous_previewers = ActiveStorage.previewers
      ActiveStorage.previewers = previewers.map do |previewer|
        ActiveStorage::Previewer.const_get(previewer)
      end
      yield
    ensure
      ActiveStorage.previewers = previous_previewers
    end

    def with_service(service_name)
      previous_service = ActiveStorage::Blob.service
      prevous_config = Rails.application.config.active_storage.service
      ActiveStorage::Blob.service = service_name ? ActiveStorage::Blob.services.fetch(service_name) : nil
      Rails.application.config.active_storage.service = service_name
      yield
    ensure
      ActiveStorage::Blob.service = previous_service
      Rails.application.config.active_storage.service = prevous_config
    end

    def with_strict_loading_by_default(&block)
      strict_loading_was = ActiveRecord::Base.strict_loading_by_default
      ActiveRecord::Base.strict_loading_by_default = true
      yield
    ensure
      ActiveRecord::Base.strict_loading_by_default = strict_loading_was
    end

    def with_variant_tracking(&block)
      variant_tracking_was = ActiveStorage.track_variants
      ActiveStorage.track_variants = true
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

    def with_binary_content_types(content_types)
      old_content_types = ActiveStorage.content_types_to_serve_as_binary
      ActiveStorage.content_types_to_serve_as_binary = content_types
      yield
    ensure
      ActiveStorage.content_types_to_serve_as_binary = old_content_types
    end

    def with_variable_content_types(content_types)
      old_content_types = ActiveStorage.variable_content_types
      ActiveStorage.variable_content_types = content_types
      yield
    ensure
      ActiveStorage.variable_content_types = old_content_types
    end

    def with_web_content_types(content_types)
      old_content_types = ActiveStorage.web_image_content_types
      ActiveStorage.web_image_content_types = content_types
      yield
    ensure
      ActiveStorage.web_image_content_types = old_content_types
    end

    def with_inline_content_types(content_types)
      old_content_types = ActiveStorage.content_types_allowed_inline
      ActiveStorage.content_types_allowed_inline = content_types
      yield
    ensure
      ActiveStorage.content_types_allowed_inline = old_content_types
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
