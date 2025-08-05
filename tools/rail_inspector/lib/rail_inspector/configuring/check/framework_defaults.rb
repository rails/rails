# frozen_string_literal: true

require "tempfile"

module RailInspector
  class Configuring
    module Check
      class FrameworkDefaults
        attr_reader :checker

        def initialize(checker)
          @checker = checker
        end

        def check
          header, *defaults_by_version = documented_defaults

          checker.doc.versioned_defaults =
            header +
              defaults_by_version
                .map { |defaults| check_defaults(defaults) }
                .flatten
        end

        private
          def check_defaults(defaults)
            header, configs = defaults[0], defaults[2, defaults.length - 3]
            configs ||= []

            version = header.match(/\d\.\d/)[0]

            generated_doc =
              checker.framework_defaults_by_version[version]
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
              #{checker.files.application_configuration}: Incorrect load_defaults docs
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
      end
    end
  end
end
