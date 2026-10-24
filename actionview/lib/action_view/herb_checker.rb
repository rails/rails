# frozen_string_literal: true

# :markup: markdown

require "herb/configuration"
require "action_view/template/handlers/erb/herb"
require "herb/engine/validators/security_validator"

module ActionView
  class HerbChecker # :nodoc:
    Failure = Data.define(:path, :error)

    HTML_ERB = /\.html(\+[^.\/]*)?\.erb\z/

    def self.check(root)
      root = File.expand_path(root)

      ::Herb::Configuration.load(root).find_files(root).filter_map do |file|
        next unless file.match?(HTML_ERB)

        begin
          Template::Handlers::ERB::Herb.new(
            File.read(file),
            trim: Template::Handlers::ERB.erb_trim_mode == "-",
            validate_ruby: true,
            visitors: [::Herb::Engine::Validators::SecurityValidator.new]
          )
          nil
        rescue ::Herb::Engine::CompilationError, ::Herb::Engine::SecurityError => error
          Failure.new(file.delete_prefix("#{root}/"), error)
        end
      end
    end
  end
end
