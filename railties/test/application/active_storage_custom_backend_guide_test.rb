# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class ActiveStorageCustomBackendGuideTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      reset_environment_configs

      FileUtils.rm_rf(app_path("app/channels"))
      FileUtils.rm_rf(app_path("app/mailers"))
      FileUtils.rm_f(app_path("app/models/application_record.rb"))
      boot = File.read(app_path("config/boot.rb")).sub('require "rails/all"', 'require "rails"')
      app_file "config/boot.rb", boot

      application = File.read(app_path("config/application.rb")).sub('require "rails/all"', <<~RUBY)
        require "rails"
        require "action_controller/railtie"
        require "active_job/railtie"
        require "active_storage/engine"
      RUBY
      app_file "config/application.rb", application
      add_to_top_of_config <<~RUBY
        require #{File.join(RAILS_FRAMEWORK_ROOT, "activestorage/test/fixtures/active_storage/in_memory_backend").inspect}
      RUBY
      add_to_config <<~RUBY
        config.active_storage.service = :local
        config.active_storage.service_configurations = {
          local: { service: "Disk", root: Rails.root.join("tmp/storage") }
        }
        config.active_storage.blob_class = "ActiveStorage::InMemoryBackend::Blob"
        config.active_storage.attachment_class = "ActiveStorage::InMemoryBackend::Attachment"
        config.active_storage.variant_record_class = "ActiveStorage::InMemoryBackend::VariantRecord"

        initializer "guide.active_storage", after: "active_storage.class_indirection" do |app|
          ActiveStorage::Services.setup_from_app_config(app)
          ActiveStorage::InMemoryBackend.install
        end
      RUBY

      guide = File.read(File.join(RAILS_FRAMEWORK_ROOT, "guides/source/active_storage_custom_backend.md"))
      owner_section = guide.split("Owner Class Contract\n", 2).last.split("Blob Class Contract\n", 2).first
      owner_example = owner_section.match(/```ruby\n(.*?)\n```/m)[1]
      app_file "app/models/message.rb", owner_example
    end

    def teardown
      teardown_app
    end

    test "documented owner defines attachments and persists uploads" do
      output = run_owner_example <<~RUBY
        owner = Message.new
        owner.avatar = { io: StringIO.new("avatar"), filename: "avatar.txt" }
        owner.images = [ { io: StringIO.new("image"), filename: "image.txt" } ]
        puts owner.save
        puts owner.avatar.download
        puts owner.images.first.download
        puts Message.find(owner.id).persisted?
        puts Message.new(id: owner.id).persisted?
        puts Message.new(id: owner.id).destroy
        puts owner.persisted?
        puts owner.destroy
        puts owner.persisted?
      RUBY

      assert_equal [ "true", "avatar", "image", "true", "false", "false", "true", "true", "false" ], output.lines.map(&:chomp).last(9)
    end

    test "documented owner does not commit failed persistence or aborted callbacks" do
      output = run_owner_example <<~RUBY
        commits = 0
        Message.after_commit { commits += 1 }
        owner = Message.new
        owner.avatar = { io: StringIO.new("avatar"), filename: "avatar.txt" }
        owner.save_succeeds = false
        puts owner.save
        puts commits
        puts owner.attachment_changes.key?("avatar")

        owner.save_succeeds = true
        Message.before_save { throw :abort }
        puts owner.save
        puts commits

        Message.before_destroy { throw :abort }
        puts owner.destroy
        puts commits
        puts owner.attachment_changes.key?("avatar")
      RUBY

      assert_equal [ "false", "0", "true", "false", "0", "false", "0", "true" ], output.lines.map(&:chomp).last(8)
    end

    private
      def run_owner_example(script)
        backend = <<~RUBY
          class Message
            class_attribute :stored_records, default: {}
            attr_accessor :save_succeeds

            def self.find(id)
              new(stored_records.fetch(id)).tap { |owner| owner.instance_variable_set(:@persisted, true) }
            rescue KeyError
              raise ActiveStorage::RecordNotFound
            end

            private
              def backend_exists?(id)
                stored_records.key?(id)
              end

              def persist_to_backend
                return false if save_succeeds == false

                self.id ||= SecureRandom.uuid
                stored_records[id] = { id: id }
                true
              end

              def delete_from_backend
                stored_records.delete(id)
                true
              end
          end
        RUBY

        with_env("NO_FORK" => "1") do
          rails [ "runner", backend + script ]
        end
      end
  end
end
