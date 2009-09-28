require 'rbconfig'
require File.dirname(__FILE__) + '/template_runner'
require 'digest/md5' 
require 'active_support/secure_random'

class AppGenerator < Rails::Generator::Base
  DEFAULT_SHEBANG = File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])

  DATABASES        = %w( mysql oracle postgresql sqlite2 sqlite3 frontbase ibm_db )
  DEFAULT_DATABASE = 'sqlite3'

  mandatory_options :source => "#{File.dirname(__FILE__)}/../../../../.."
  default_options   :db => (ENV["RAILS_DEFAULT_DATABASE"] || DEFAULT_DATABASE),
    :shebang => DEFAULT_SHEBANG, :with_dispatchers => false, :freeze => false


  def initialize(runtime_args, runtime_options = {})
    super

    usage if args.empty?
    usage("Databases supported for preconfiguration are: #{DATABASES.join(", ")}") if (options[:db] && !DATABASES.include?(options[:db]))

    @destination_root = args.shift
    @app_name = File.basename(File.expand_path(@destination_root))
  end

  def manifest
    record do |m|
      create_directories(m)
      create_root_files(m)
      create_app_files(m)
      create_config_files(m)
      create_script_files(m)
      create_test_files(m)
      create_public_files(m)
      create_documentation_file(m)
      create_log_files(m)
    end
  end

  def after_generate
    if options[:template]
      Rails::TemplateRunner.new(options[:template], @destination_root)
    end
  end

  protected
    def banner
      "Usage: #{$0} /path/to/your/app [options]"
    end

    def add_options!(opt)
      opt.separator ''
      opt.separator 'Options:'
      opt.on("-r", "--ruby=path", String,
             "Path to the Ruby binary of your choice (otherwise scripts use env, dispatchers current path).",
             "Default: #{DEFAULT_SHEBANG}") { |v| options[:shebang] = v }

      opt.on("-d", "--database=name", String,
            "Preconfigure for selected database (options: #{DATABASES.join('/')}).",
            "Default: #{DEFAULT_DATABASE}") { |v| options[:db] = v }

      opt.on("-D", "--with-dispatchers",
            "Add CGI/FastCGI/mod_ruby dispatches code to generated application skeleton",
            "Default: false") { |v| options[:with_dispatchers] = v }

      opt.on("-f", "--freeze",
            "Freeze Rails in vendor/rails from the gems generating the skeleton",
            "Default: false") { |v| options[:freeze] = v }

      opt.on("-m", "--template=path", String,
            "Use an application template that lives at path (can be a filesystem path or URL).",
            "Default: (none)") { |v| options[:template] = v }

    end


  private
    def create_directories(m)
      m.directory ''

      # Intermediate directories are automatically created so don't sweat their absence here.
      %w(
        app/controllers
        app/helpers
        app/models
        app/views/layouts
        config/environments
        config/initializers
        config/locales
        db
        doc
        lib
        lib/tasks
        log
        public/images
        public/javascripts
        public/stylesheets
        script/performance
        test/fixtures
        test/functional
        test/integration
        test/performance
        test/unit
        vendor
        vendor/plugins
        tmp/sessions
        tmp/sockets
        tmp/cache
        tmp/pids
      ).each { |path| m.directory(path) }
    end
    
    def create_root_files(m)
      m.file "fresh_rakefile", "Rakefile"
      m.file "README",         "README"
    end
    
    def create_app_files(m)
      m.file "helpers/application_controller.rb", "app/controllers/application_controller.rb"
      m.file "helpers/application_helper.rb",     "app/helpers/application_helper.rb"
    end

    def create_config_files(m)
      create_database_configuration_file(m)
      create_routes_file(m)
      create_locale_file(m)
      create_seeds_file(m)
      create_initializer_files(m)
      create_environment_files(m)
    end

    def create_documentation_file(m)
      m.file "doc/README_FOR_APP", "doc/README_FOR_APP"
    end

    def create_log_files(m)
      %w( server production development test ).each do |file|
        m.file "configs/empty.log", "log/#{file}.log", :chmod => 0666
      end
    end    

    def create_public_files(m)
      create_dispatch_files(m)
      create_error_files(m)
      create_welcome_file(m)
      create_browser_convention_files(m)
      create_rails_image(m)
      create_javascript_files(m)
    end
    
    def create_script_files(m)
      %w( 
        about console dbconsole destroy generate runner server plugin
        performance/benchmarker performance/profiler
      ).each do |file|
        m.file "bin/#{file}", "script/#{file}", { 
          :chmod => 0755, 
          :shebang => options[:shebang] == DEFAULT_SHEBANG ? nil : options[:shebang]
        }
      end
    end

    def create_test_files(m)
      m.file "helpers/test_helper.rb",      "test/test_helper.rb"
      m.file "helpers/performance_test.rb", "test/performance/browsing_test.rb"
    end


    def create_database_configuration_file(m)
      m.template "configs/databases/#{options[:db]}.yml", "config/database.yml", :assigns => {
        :app_name => @app_name,
        :socket   => options[:db] == "mysql" ? mysql_socket_location : nil }
    end
    
    def create_routes_file(m)
      m.file "configs/routes.rb", "config/routes.rb"
    end

    def create_seeds_file(m)
      m.file "configs/seeds.rb", "db/seeds.rb"
    end

    def create_initializer_files(m)
      %w( 
        backtrace_silencers 
        inflections 
        mime_types 
        new_rails_defaults
      ).each do |initializer|
        m.file "configs/initializers/#{initializer}.rb", "config/initializers/#{initializer}.rb"
      end

      m.template "configs/initializers/session_store.rb", "config/initializers/session_store.rb", 
        :assigns => { :app_name => @app_name, :app_secret => ActiveSupport::SecureRandom.hex(64) }
    end

    def create_locale_file(m)
      m.file "configs/locales/en.yml", "config/locales/en.yml"
    end

    def create_environment_files(m)
      m.template "environments/environment.rb", "config/environment.rb", 
        :assigns => { :freeze => options[:freeze] }

      m.file "environments/boot.rb",        "config/boot.rb"
      m.file "environments/production.rb",  "config/environments/production.rb"
      m.file "environments/development.rb", "config/environments/development.rb"
      m.file "environments/test.rb",        "config/environments/test.rb"
    end


    def create_dispatch_files(m)
      if options[:with_dispatchers]
        dispatcher_options = { :chmod => 0755, :shebang => options[:shebang] }

        m.file "dispatches/config.ru",     "config.ru"
        m.file "dispatches/dispatch.rb",   "public/dispatch.rb",   dispatcher_options
        m.file "dispatches/dispatch.rb",   "public/dispatch.cgi",  dispatcher_options
        m.file "dispatches/dispatch.fcgi", "public/dispatch.fcgi", dispatcher_options
      end
    end

    def create_error_files(m)
      %w( 404 422 500  ).each do |file|
        m.file "html/#{file}.html", "public/#{file}.html"
      end
    end

    def create_welcome_file(m)
      m.file 'html/index.html', 'public/index.html'
    end

    def create_browser_convention_files(m)
      m.file "html/favicon.ico", "public/favicon.ico"
      m.file "html/robots.txt",  "public/robots.txt"
    end

    def create_rails_image(m)
      m.file "html/images/rails.png", "public/images/rails.png"
    end

    def create_javascript_files(m)
      %w( prototype effects dragdrop controls application ).each do |javascript|
        m.file "html/javascripts/#{javascript}.js", "public/javascripts/#{javascript}.js"
      end
    end


    def mysql_socket_location
      [
        "/tmp/mysql.sock",                        # default
        "/var/run/mysqld/mysqld.sock",            # debian/gentoo
        "/var/tmp/mysql.sock",                    # freebsd
        "/var/lib/mysql/mysql.sock",              # fedora
        "/opt/local/lib/mysql/mysql.sock",        # fedora
        "/opt/local/var/run/mysqld/mysqld.sock",  # mac + darwinports + mysql
        "/opt/local/var/run/mysql4/mysqld.sock",  # mac + darwinports + mysql4
        "/opt/local/var/run/mysql5/mysqld.sock",  # mac + darwinports + mysql5
        "/opt/lampp/var/mysql/mysql.sock"         # xampp for linux
      ].find { |f| File.exist?(f) } unless RUBY_PLATFORM =~ /(:?mswin|mingw)/
    end
end