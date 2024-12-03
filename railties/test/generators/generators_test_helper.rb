# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/stream"
require "active_support/testing/method_call_assertions"
require "rails/generators"
require "rails/generators/test_case"
require "rails/generators/app_base"

Rails.application.config.generators.templates = [File.expand_path("../fixtures/lib/templates", __dir__)]

# Call configure to load the settings from
# Rails.application.config.generators to Rails::Generators
Rails.application.load_generators

require "active_record"
require "action_dispatch"
require "action_view"

module GeneratorsTestHelper
  include ActiveSupport::Testing::Stream
  include ActiveSupport::Testing::MethodCallAssertions

  def self.included(base)
    base.class_eval do
      destination File.expand_path("../fixtures/tmp", __dir__)
      setup :prepare_destination

      setup { Rails.application.config.root = Pathname("../fixtures").expand_path(__dir__) }

      setup { @original_rakeopt, ENV["RAKEOPT"] = ENV["RAKEOPT"], "--silent" }
      teardown { ENV["RAKEOPT"] = @original_rakeopt }

      begin
        base.tests Rails::Generators.const_get(base.name.delete_suffix("Test"))
      rescue
      end
    end
  end

  def run_generator_instance
    capture(:stdout) do
      generator.invoke_all
    end
  end

  def with_database_configuration(database_name = "secondary")
    original_configurations = ActiveRecord::Base.configurations
    ActiveRecord::Base.configurations = {
      test: {
        "#{database_name}": {
          adapter: "sqlite3",
          database: "db/#{database_name}.sqlite3",
          migrations_paths: "db/#{database_name}_migrate",
        },
      },
    }
    yield
  ensure
    ActiveRecord::Base.configurations = original_configurations
  end

  def copy_routes
    routes = File.expand_path("../../lib/rails/generators/rails/app/templates/config/routes.rb.tt", __dir__)
    routes = evaluate_template(routes, {
      options: ActiveSupport::OrderedOptions.new
    })
    destination = File.join(destination_root, "config")
    FileUtils.mkdir_p(destination)
    File.write File.join(destination, "routes.rb"), routes
  end

  def copy_gemfile(*gemfile_entries)
    locals = gemfile_locals.merge(gemfile_entries: gemfile_entries)
    gemfile = File.expand_path("../../lib/rails/generators/rails/app/templates/Gemfile.tt", __dir__)
    gemfile = evaluate_template(gemfile, locals)
    destination = File.join(destination_root)
    File.write File.join(destination, "Gemfile"), gemfile
  end

  def copy_application_system_test_case
    content = File.read(File.expand_path("../fixtures/test/application_system_test_case.rb", __dir__))
    destination = File.join(destination_root, "test")
    mkdir_p(destination)
    File.write File.join(destination, "application_system_test_case.rb"), content
  end

  def copy_dockerfile
    dockerfile = File.expand_path("../fixtures/Dockerfile.test", __dir__)
    dockerfile = evaluate_template_docker(dockerfile)
    destination = File.join(destination_root)
    File.write File.join(destination, "Dockerfile"), dockerfile
  end

  def copy_devcontainer_files
    destination = File.join(destination_root, ".devcontainer")
    mkdir_p(destination)

    devcontainer_json = File.read(File.expand_path("../fixtures/.devcontainer/devcontainer.json", __dir__))
    File.write File.join(destination, "devcontainer.json"), devcontainer_json

    compose_yaml = File.read(File.expand_path("../fixtures/.devcontainer/compose.yaml", __dir__))
    File.write File.join(destination, "compose.yaml"), compose_yaml
  end

  def copy_minimal_devcontainer_compose_file
    destination = File.join(destination_root, ".devcontainer")
    mkdir_p(destination)

    compose_yaml = File.read(File.expand_path("../fixtures/.devcontainer/compose-minimal.yaml", __dir__))
    File.write File.join(destination, "compose.yaml"), compose_yaml
  end

  def evaluate_template(file, locals = {})
    erb = ERB.new(File.read(file), trim_mode: "-", eoutvar: "@output_buffer")
    context = Class.new do
      locals.each do |local, value|
        class_attribute local, default: value
      end
    end
    erb.result(context.new.instance_eval("binding"))
  end

  def evaluate_template_docker(file)
    erb = ERB.new(File.read(file), trim_mode: "-", eoutvar: "@output_buffer")
    erb.result()
  end

  def assert_compose_file
    assert_file ".devcontainer/compose.yaml" do |content|
      yield YAML.load(content)
    end
  end

  def assert_devcontainer_json_file
    assert_file ".devcontainer/devcontainer.json" do |content|
      yield JSON.load(content)
    end
  end

  def run_app_update(app_root = destination_root, flags: "--force")
    Dir.chdir(app_root) do
      gemfile_contents = File.read("Gemfile")
      gemfile_contents.sub!(/^(gem "rails").*/, "\\1, path: #{File.expand_path("../../..", __dir__).inspect}")
      File.write("Gemfile", gemfile_contents)

      silence_stream($stdout) { system({ "BUNDLE_GEMFILE" => "Gemfile" }, "bin/rails app:update #{flags}", exception: true) }
    end
  end

  private
    def gemfile_locals
      {
        rails_prerelease: false,
        skip_active_storage: true,
        depend_on_bootsnap: false,
        depends_on_system_test: false,
        options: ActiveSupport::OrderedOptions.new,
      }
    end
end
