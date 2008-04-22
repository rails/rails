module Rails
  module Info
    mattr_accessor :properties
    class << (@@properties = [])
      def names
        map &:first
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

      def components
        %w( active_record action_pack active_resource action_mailer active_support )
      end

      def component_version(component)
        require "#{component}/version"
        "#{component.classify}::VERSION::STRING".constantize
      end

      def edge_rails_revision(info = git_info)
        info[/commit ([a-z0-9-]+)/, 1] || freeze_edge_version
      end

      def freeze_edge_version
        if File.exist?(rails_vendor_root)
          begin
            Dir[File.join(rails_vendor_root, 'REVISION_*')].first.scan(/_(\d+)$/).first.first
          rescue
            Dir[File.join(rails_vendor_root, 'TAG_*')].first.scan(/_(.+)$/).first.first rescue 'unknown'
          end
        end
      end

      def to_s
        column_width = properties.names.map {|name| name.length}.max
        ["About your application's environment", *properties.map do |property|
          "%-#{column_width}s   %s" % property
        end] * "\n"
      end

      alias inspect to_s

      def to_html
        returning table = '<table>' do
          properties.each do |(name, value)|
            table << %(<tr><td class="name">#{CGI.escapeHTML(name.to_s)}</td>)
            table << %(<td class="value">#{CGI.escapeHTML(value.to_s)}</td></tr>)
          end
          table << '</table>'
        end
      end

      protected
        def rails_vendor_root
          @rails_vendor_root ||= "#{RAILS_ROOT}/vendor/rails"
        end

        def git_info
          env_lang, ENV['LC_ALL'] = ENV['LC_ALL'], 'C'
          Dir.chdir(rails_vendor_root) do
            silence_stderr { `git log -n 1` }
          end
        ensure
          ENV['LC_ALL'] = env_lang
        end
    end

    # The Ruby version and platform, e.g. "1.8.2 (powerpc-darwin8.2.0)".
    property 'Ruby version', "#{RUBY_VERSION} (#{RUBY_PLATFORM})"

    # The RubyGems version, if it's installed.
    property 'RubyGems version' do
      Gem::RubyGemsVersion
    end

    # The Rails version.
    property 'Rails version' do
      Rails::VERSION::STRING
    end

    # Versions of each Rails component (Active Record, Action Pack,
    # Active Resource, Action Mailer, and Active Support).
    components.each do |component|
      property "#{component.titlecase} version" do
        component_version(component)
      end
    end

    # The Rails Git revision, if it's checked out into vendor/rails.
    property 'Edge Rails revision' do
      edge_rails_revision
    end

    # The application's location on the filesystem.
    property 'Application root' do
      File.expand_path(RAILS_ROOT)
    end

    # The current Rails environment (development, test, or production).
    property 'Environment' do
      RAILS_ENV
    end

    # The name of the database adapter for the current environment.
    property 'Database adapter' do
      ActiveRecord::Base.configurations[RAILS_ENV]['adapter']
    end

    property 'Database schema version' do
      ActiveRecord::Migrator.current_version rescue nil
    end
  end
end
