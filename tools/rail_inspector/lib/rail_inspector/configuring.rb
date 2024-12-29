# frozen_string_literal: true

require "pathname"
require_relative "./configuring/check/general_configuration"
require_relative "./configuring/check/framework_defaults"

module RailInspector
  class Configuring
    class CachedParser
      def initialize
        @cache = {}
      end

      def call(path)
        @cache[path] ||= Prism.parse_file(path.to_s).value
      end
    end

    DOC_PATH = "guides/source/configuring.md"
    APPLICATION_CONFIGURATION_PATH =
      "railties/lib/rails/application/configuration.rb"
    NEW_FRAMEWORK_DEFAULTS_PATH =
      "railties/lib/rails/generators/rails/app/templates/config/initializers/new_framework_defaults_%{version}.rb.tt"

    class Doc
      attr_accessor :general_config, :versioned_defaults

      def initialize(content)
        @before, @versioned_defaults, @general_config, @after =
          content
            .split("\n")
            .slice_before do |line|
              [
                "### Versioned Default Values",
                "### Rails General Configuration",
                "### Configuring Assets"
              ].include?(line)
            end
            .to_a
      end

      def to_s
        (@before + @versioned_defaults + @general_config + @after).join("\n") +
          "\n"
      end
    end

    attr_reader :errors, :parser

    def initialize(rails_path)
      @errors = []
      @parser = CachedParser.new
      @rails_path = Pathname.new(rails_path)
    end

    def check
      [Check::GeneralConfiguration, Check::FrameworkDefaults].each do |check|
        check.new(self).check
      end
    end

    def doc
      @doc ||=
        begin
          content = File.read(doc_path)
          Configuring::Doc.new(content)
        end
    end

    def parse(relative_path)
      parser.call(@rails_path.join(relative_path))
    end

    def read(relative_path)
      File.read(@rails_path.join(relative_path))
    end

    def rails_version
      @rails_version ||= File.read(@rails_path.join("RAILS_VERSION")).to_f.to_s
    end

    def write!
      File.write(doc_path, doc.to_s)
    end

    def error_message
      return unless errors.any?

      errors.join("\n") + "\n" +
        "Make sure new configurations are added to configuring.md#rails-general-configuration in alphabetical order.\n" +
        "Errors may be autocorrectable with the --autocorrect flag"
    end

    private
      def doc_path
        @rails_path.join(DOC_PATH)
      end
  end
end
