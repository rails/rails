require "cgi"

module Rails
  module Info
    mattr_accessor :properties
    class << (@@properties = [])
      def names
        map {|val| val.first }
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

      def frameworks
        %w( active_record action_pack action_mailer active_support )
      end

      def framework_version(framework)
        if Object.const_defined?(framework.classify)
          require "#{framework}/version"
          "#{framework.classify}::VERSION::STRING".constantize
        end
      end

      def to_s
        column_width = properties.names.map {|name| name.length}.max
        info = properties.map do |name, value|
          value = value.join(", ") if value.is_a?(Array)
          "%-#{column_width}s   %s" % [name, value]
        end
        info.unshift "About your application's environment"
        info * "\n"
      end

      alias inspect to_s

      def to_html
        (table = '<table>').tap do
          properties.each do |(name, value)|
            table << %(<tr><td class="name">#{CGI.escapeHTML(name.to_s)}</td>)
            formatted_value = if value.kind_of?(Array)
                  "<ul>" + value.map { |v| "<li>#{CGI.escapeHTML(v.to_s)}</li>" }.join + "</ul>"
                else
                  CGI.escapeHTML(value.to_s)
                end
            table << %(<td class="value">#{formatted_value}</td></tr>)
          end
          table << '</table>'
        end
      end
    end

    # The Ruby version and platform, e.g. "1.8.2 (powerpc-darwin8.2.0)".
    property 'Ruby version', "#{RUBY_VERSION} (#{RUBY_PLATFORM})"

    # The RubyGems version, if it's installed.
    property 'RubyGems version' do
      Gem::RubyGemsVersion
    end

    property 'Rack version' do
      ::Rack.release
    end

    # The Rails version.
    property 'Rails version' do
      Rails::VERSION::STRING
    end

    property 'JavaScript Runtime' do
      ExecJS.runtime.name
    end

    # Versions of each Rails framework (Active Record, Action Pack,
    # Action Mailer, and Active Support).
    frameworks.each do |framework|
      property "#{framework.titlecase} version" do
        framework_version(framework)
      end
    end

    property 'Middleware' do
      Rails.configuration.middleware.map(&:inspect)
    end

    # The application's location on the filesystem.
    property 'Application root' do
      File.expand_path(Rails.root)
    end

    # The current Rails environment (development, test, or production).
    property 'Environment' do
      Rails.env
    end

    # The name of the database adapter for the current environment.
    property 'Database adapter' do
      ActiveRecord::Base.configurations[Rails.env]['adapter']
    end

    property 'Database schema version' do
      ActiveRecord::Migrator.current_version rescue nil
    end
  end
end
