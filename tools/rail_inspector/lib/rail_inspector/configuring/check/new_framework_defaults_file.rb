# frozen_string_literal: true

module RailInspector
  class Configuring
    module Check
      class NewFrameworkDefaultsFile
        attr_reader :checker, :visitor

        # Defaults are strings like:
        #   self.yjit
        #   action_controller.escape_json_responses
        def initialize(checker, defaults, file_content)
          @checker = checker
          @defaults = defaults
          @file_content = file_content
        end

        def check
          @defaults.each do |config|
            if config.start_with? "self"
              next if @file_content.include? config.gsub(/^self/, "config")
              next if @file_content.include? config.gsub(/^self/, "configuration")
            end

            next if @file_content.include? config

            next if config == "self.yjit"

            checker.errors << <<~MESSAGE
              #{checker.files.new_framework_defaults}: Missing new default
              #{config}

            MESSAGE
          end
        end
      end
    end
  end
end
