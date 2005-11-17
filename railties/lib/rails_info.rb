require 'rails_version'

module Rails
  module Info
    mattr_accessor :properties
    class << (@@properties = [])
      def names
        map {|(name, )| name}
      end
      
      def value_for(property_name)
        find {|(name, )| name == property_name}.last rescue nil
      end
    end
  
    class << self #:nodoc:
      def property(name, value = nil)
        value ||= yield
        properties << [name, value] if value 
      rescue Exception
      end

      def components
        %w( active_record action_pack action_web_service action_mailer active_support )
      end
      
      def component_version(component)
        require "#{component}/version"
        "#{component.classify}::VERSION::STRING".constantize
      end
    
      def edge_rails_revision(info = svn_info)
        info[/^Revision: (\d+)/, 1]
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
            table << %(<tr><td class="name">#{CGI.escapeHTML(name)}</td>)
            table << %(<td class="value">#{CGI.escapeHTML(value)}</td></tr>)
          end
          table << '</table>'
        end
      end
      
    protected
      def svn_info
        Dir.chdir("#{RAILS_ROOT}/vendor/rails") do
          silence_stderr { `svn info` }
        end
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
    # Action Web Service, Action Mailer, and Active Support).
    components.each do |component|
      property "#{component.titlecase} version" do 
        component_version(component)
      end
    end
  
    # The Rails SVN revision, if it's checked out into vendor/rails.
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
  end
end
