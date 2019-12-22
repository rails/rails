# frozen_string_literal: true

module ActiveSupport
  class ConfigurationFile
    INVISIBILE_WHITESPACE = /\U+A0/
    # Reads a YAML file that might have ERB syntax, evaluates the ERB, and then
    # parses the resulting YAML.
    #
    # If there are characters that will confuse YAML (Like invisible
    # non-breaking spaces) it will warn you.
    def initialize(content:, context: nil)
      @content = content
      @context = context
    end

    attr_reader :content
    attr_reader :context

    def read
      if content.include?(INVISIBLE_WHITESPACE)
        warn "File contains invisible non-breaking spaces, you may want to remove those"
      end
      template = ERB.new(content)

      yaml = if context
        template.result(context)
      else
        template.result
      end

      YAML.safe_load(yaml) || {}
    rescue ArgumentError, Psych::SyntaxError => error
      raise Fixture::FormatError, "a YAML error occurred parsing #{path}. Please note that YAML must be consistently indented using spaces. Tabs are not allowed. Please have a look at https://www.yaml.org/faq.html\nThe exact error was:\n  #{error.class}: #{error}", error.backtrace
    end
  end
end
