# frozen_string_literal: true

require "tempfile"
require_relative "../../visitor/framework_default"

module RailInspector
  class Configuring
    module Check
      class FrameworkDefaults
        class NewFrameworkDefaultsFile
          attr_reader :checker, :visitor

          def initialize(checker, visitor)
            @checker = checker
            @visitor = visitor
          end

          def check
            visitor.config_map[checker.rails_version].each_key do |config|
              app_config = config.gsub(/^self/, "config")

              next if defaults_file_content.include? app_config

              next if config == "self.yjit"

              add_error(config)
            end
          end

          private
            def add_error(config)
              checker.errors << <<~MESSAGE
              #{new_framework_defaults_path}
              Missing: #{config}

              MESSAGE
            end

            def defaults_file_content
              @defaults_file_content ||= checker.read(new_framework_defaults_path)
            end

            def new_framework_defaults_path
              NEW_FRAMEWORK_DEFAULTS_PATH %
                { version: checker.rails_version.tr(".", "_") }
            end
        end

        attr_reader :checker

        def initialize(checker)
          @checker = checker
        end

        def check
          header, *defaults_by_version = documented_defaults

          NewFrameworkDefaultsFile.new(checker, visitor).check

          checker.doc.versioned_defaults =
            header +
              defaults_by_version
                .map { |defaults| check_defaults(defaults) }
                .flatten
        end

        private
          def app_config_tree
            checker.parse(APPLICATION_CONFIGURATION_PATH)
          end

          def check_defaults(defaults)
            header, configs = defaults[0], defaults[2, defaults.length - 3]
            configs ||= []

            version = header.match(/\d\.\d/)[0]

            generated_doc =
              visitor.config_map[version]
                .map do |config, value|
                  full_config =
                    case config
                    when /^[A-Z]/
                      config
                    when /^self/
                      config.sub("self", "config")
                    else
                      "config.#{config}"
                    end

                  "- [`#{full_config}`](##{full_config.tr("._", "-").downcase}): `#{value}`"
                end
                .sort

            config_diff =
              Tempfile.create("expected") do |doc|
                doc << generated_doc.join("\n")
                doc.flush

                Tempfile.create("actual") do |code|
                  code << configs.join("\n")
                  code.flush

                  `git diff --color --no-index #{doc.path} #{code.path}`
                end
              end

            checker.errors << <<~MESSAGE unless config_diff.empty?
              #{APPLICATION_CONFIGURATION_PATH}: Incorrect load_defaults docs
              --- Expected
              +++ Actual
              #{config_diff.split("\n")[5..].join("\n")}
            MESSAGE

            [header, "", *generated_doc, ""]
          end

          def documented_defaults
            checker
              .doc
              .versioned_defaults
              .slice_before { |line| line.start_with?("####") }
              .to_a
          end

          def visitor
            @visitor ||=
              begin
                visitor = Visitor::FrameworkDefault.new
                visitor.visit(app_config_tree)
                visitor
              end
          end
      end
    end
  end
end
