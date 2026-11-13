# frozen_string_literal: true

module ActiveSupport
  # Reads a YAML configuration file, evaluating any ERB, then
  # parsing the resulting YAML.
  #
  # Parsing uses +YAML.safe_load+ with aliases enabled. The only extra
  # classes permitted are +Date+, +DateTime+, +Time+, +Symbol+, and
  # +YAML::Omap+ (ordered fixtures). A +!ruby/object+ tag raises
  # +Psych::DisallowedClass+.
  #
  # Warns in case of YAML confusing characters, like invisible
  # non-breaking spaces.
  class ConfigurationFile # :nodoc:
    class FormatError < StandardError; end

    def self.permitted_classes
      require "date"
      require "yaml"
      require "psych/omap"
      @permitted_classes ||= [Date, DateTime, Time, Symbol, YAML::Omap].freeze
    end

    def initialize(content_path)
      @content_path = content_path.to_s
      @content = read content_path
    end

    def self.parse(content_path, **options)
      new(content_path).parse(**options)
    end

    def parse(context: nil, **options)
      source = @content.include?("<%") ? render(context) : @content
      extra_classes = Array(options.delete(:permitted_classes))
      yaml_options = {
        aliases: true,
        permitted_classes: self.class.permitted_classes + extra_classes
      }.merge(options)

      if source == @content
        YAML.safe_load_file(@content_path, **yaml_options) || {}
      else
        YAML.safe_load(source, **yaml_options) || {}
      end
    rescue Psych::SyntaxError => error
      raise FormatError, "YAML syntax error occurred while parsing #{@content_path}. " \
            "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
            "Error: #{error.message}"
    end

    private
      def read(content_path)
        require "yaml" unless defined?(YAML)

        File.read(content_path).tap do |content|
          if content.include?("\u00A0")
            warn "#{content_path} contains invisible non-breaking spaces, you may want to remove those"
          end
        end
      end

      def render(context)
        require "erb" unless defined?(ERB)
        erb = ERB.new(@content).tap { |e| e.filename = @content_path }
        context ? erb.result(context) : erb.result
      end
  end
end
