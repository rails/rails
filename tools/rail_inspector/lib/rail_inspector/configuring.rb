# frozen_string_literal: true

require "pathname"
require_relative "./configuring/check/general_configuration"
require_relative "./configuring/check/framework_defaults"
require_relative "./configuring/check/new_framework_defaults_file"
require_relative "./configuring/document"
require_relative "./visitor/framework_default"

module RailInspector
  class Configuring
    class Files
      class Proxy
        def initialize(pathname)
          @pathname = pathname
        end

        def parse
          @parse ||= Prism.parse_file(@pathname.to_s).value
        end

        def read
          @pathname.read
        end

        def write(string)
          @pathname.write(string)
        end

        def to_s
          @pathname.to_s
        end
      end

      def initialize(root)
        @root = Pathname.new(root)
        @files = {}
      end

      def []=(name, path)
        @files[name] = Proxy.new(@root.join(path))
      end

      def method_missing(name, ...)
        @files[name] || super
      end
    end

    attr_reader :errors, :files

    def initialize(rails_path)
      @errors = []
      @files = Files.new(rails_path)

      @files[:application_configuration] = "railties/lib/rails/application/configuration.rb"
      @files[:doc_path] = "guides/source/configuring.md"
      @files[:rails_version] = "RAILS_VERSION"

      @files[:new_framework_defaults] = "railties/lib/rails/generators/rails/app/templates/config/initializers/new_framework_defaults_%{version}.rb.tt" % {
        version: rails_version.tr(".", "_")
      }
    end

    def check
      [
        Check::GeneralConfiguration.new(self),
        Check::FrameworkDefaults.new(
          self,
          framework_defaults_by_version,
          doc.versioned_defaults,
        ),
        Check::NewFrameworkDefaultsFile.new(
          self,
          framework_defaults_by_version[rails_version].keys,
          files.new_framework_defaults.read
        ),
      ].each(&:check)
    end

    def doc
      @doc ||= Configuring::Document.parse(files.doc_path.read)
    end

    def rails_version
      @rails_version ||= files.rails_version.read.to_f.to_s
    end

    def write!
      files.doc_path.write(doc.to_s)
    end

    def error_message
      return unless errors.any?

      errors.join("\n") + "\n" +
        "Make sure new configurations are added to configuring.md#rails-general-configuration in alphabetical order.\n" +
        "Errors may be autocorrectable with the --autocorrect flag"
    end

    private
      def framework_defaults_by_version
        @framework_defaults_by_version ||= Visitor::FrameworkDefault.new.tap { |visitor|
          visitor.visit(files.application_configuration.parse)
        }.config_map
      end
  end
end
