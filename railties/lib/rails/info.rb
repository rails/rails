# frozen_string_literal: true

require "cgi"

module Rails
  # This module helps build the runtime properties that are displayed in
  # Rails::InfoController responses. These include the active Rails version,
  # Ruby version, Rack version, and so on.
  module Info
    mattr_accessor :properties, default: []

    class << @@properties
      def names
        map(&:first)
      end

      def value_for(property_name)
        if property = assoc(property_name)
          property.last
        end
      end
    end

    class << self #:nodoc:
      def property(name, value = nil)
        value ||= yield
        properties << [name, value] if value
      rescue Exception
      end

      def to_s
        column_width = properties.names.map(&:length).max
        info = properties.map do |name, value|
          value = value.join(", ") if value.is_a?(Array)
          "%-#{column_width}s   %s" % [name, value]
        end
        info.unshift "About your application's environment"
        info * "\n"
      end

      alias inspect to_s

      def to_html
        (+"<table>").tap do |table|
          properties.each do |(name, value)|
            table << %(<tr><td class="name">#{CGI.escapeHTML(name.to_s)}</td>)
            formatted_value = if value.kind_of?(Array)
              "<ul>" + value.map { |v| "<li>#{CGI.escapeHTML(v.to_s)}</li>" }.join + "</ul>"
            else
              CGI.escapeHTML(value.to_s)
            end
            table << %(<td class="value">#{formatted_value}</td></tr>)
          end
          table << "</table>"
        end
      end
    end

    # The Rails version.
    property "Rails version" do
      Rails.version.to_s
    end

    # The Ruby version and platform, e.g. "2.0.0-p247 (x86_64-darwin12.4.0)".
    property "Ruby version" do
      "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_PLATFORM})"
    end

    # The RubyGems version, if it's installed.
    property "RubyGems version" do
      Gem::RubyGemsVersion
    end

    property "Rack version" do
      ::Rack.release
    end

    property "JavaScript Runtime" do
      ExecJS.runtime.name
    end

    property "Middleware" do
      Rails.configuration.middleware.map(&:inspect)
    end

    # The application's location on the filesystem.
    property "Application root" do
      File.expand_path(Rails.root)
    end

    # The current Rails environment (development, test, or production).
    property "Environment" do
      Rails.env
    end

    # The name of the database adapter for the current environment.
    property "Database adapter" do
      ActiveRecord::Base.configurations[Rails.env]["adapter"]
    end

    property "Database schema version" do
      ActiveRecord::Base.connection.migration_context.current_version rescue nil
    end
  end
end
