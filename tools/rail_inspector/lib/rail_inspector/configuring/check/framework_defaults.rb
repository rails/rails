# frozen_string_literal: true

require "tempfile"

module RailInspector
  class Configuring
    module Check
      class FrameworkDefaults
        attr_reader :checker

        def initialize(checker, defaults_by_version, documented_defaults)
          @checker = checker
          @defaults_by_version = defaults_by_version
          @documented_defaults = documented_defaults
        end

        def check
          expected_text = +""

          expected_text =
            @defaults_by_version.reverse_each.map { |version, defaults|
              expected_text = +"#### Default Values for Target Version #{version}\n"

              expected_text << "\n" unless defaults.empty?

              defaults.map { |config, value|
                full_config =
                  case config
                  when /^[A-Z]/
                    config
                  when /^self/
                    config.sub("self", "config")
                  else
                    "config.#{config}"
                  end

                "- [`#{full_config}`](##{full_config.tr("._", "-").downcase}): `#{value}`\n"
              }.sort.each { |t| expected_text << t }

              expected_text
            }.join("\n")

          config_diff =
            Tempfile.create("expected") do |doc|
              doc << expected_text
              doc.flush

              Tempfile.create("actual") do |code|
                code << @documented_defaults
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

          checker.doc.versioned_defaults = expected_text
        end
      end
    end
  end
end
