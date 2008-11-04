require 'rbconfig'
require 'digest/md5' 
require 'active_support/secure_random'

class AppGenerator < Rails::Generator::Base
  DEFAULT_SHEBANG = File.join(Config::CONFIG['bindir'],
                              Config::CONFIG['ruby_install_name'])

  DATABASES = %w(mysql oracle postgresql sqlite2 sqlite3 frontbase ibm_db)
  DEFAULT_DATABASE = 'sqlite3'

  default_options   :db => (ENV["RAILS_DEFAULT_DATABASE"] || DEFAULT_DATABASE),
    :shebang => DEFAULT_SHEBANG, :freeze => false
  mandatory_options :source => "#{File.dirname(__FILE__)}/../../../../.."

  def initialize(runtime_args, runtime_options = {})
    super
    usage if args.empty?
    usage("Databases supported for preconfiguration are: #{DATABASES.join(", ")}") if (options[:db] && !DATABASES.include?(options[:db]))
    @destination_root = args.shift
    @app_name = File.basename(File.expand_path(@destination_root))
  end

  def manifest
    # Use /usr/bin/env if no special shebang was specified
    script_options     = { :chmod => 0755, :shebang => options[:shebang] == DEFAULT_SHEBANG ? nil : options[:shebang] }
    dispatcher_options = { :chmod => 0755, :shebang => options[:shebang] }

    # duplicate CGI::Session#generate_unique_id
    md5 = Digest::MD5.new
    now = Time.now
    md5 << now.to_s
    md5 << String(now.usec)
    md5 << String(rand(0))
    md5 << String($$)
    md5 << @app_name

    # Do our best to generate a secure secret key for CookieStore
    secret = ActiveSupport::SecureRandom.hex(64)

    record do |m|
      # Root directory and all subdirectories.
      m.directory ''
      BASEDIRS.each { |path| m.directory path }

      # Root
      m.file "fresh_rakefile", "Rakefile"
      m.file "README",         "README"

      # Application
      m.template "helpers/application.rb",        "app/controllers/application.rb", :assigns => { :app_name => @app_name, :app_secret => md5.hexdigest }
      m.template "helpers/application_helper.rb", "app/helpers/application_helper.rb"
      m.template "helpers/test_helper.rb",        "test/test_helper.rb"
      m.template "helpers/performance_test.rb",   "test/performance/browsing_test.rb"

      # database.yml and routes.rb
      m.template "configs/databases/#{options[:db]}.yml", "config/database.yml", :assigns => {
        :app_name => @app_name,
        :socket   => options[:db] == "mysql" ? mysql_socket_location : nil
      }
      m.template "configs/routes.rb", "config/routes.rb"

      # Initializers
      m.template "configs/initializers/inflections.rb", "config/initializers/inflections.rb"
      m.template "configs/initializers/mime_types.rb", "config/initializers/mime_types.rb"
      m.template "configs/initializers/new_rails_defaults.rb", "config/initializers/new_rails_defaults.rb"

      # Locale
      m.template "configs/locales/en.yml", "config/locales/en.yml"

      # Environments
      m.file "environments/boot.rb",    "config/boot.rb"
      m.template "environments/environment.rb", "config/environment.rb", :assigns => { :freeze => options[:freeze], :app_name => @app_name, :app_secret => secret }
      m.file "environments/production.rb",  "config/environments/production.rb"
      m.file "environments/development.rb", "config/environments/development.rb"
      m.file "environments/test.rb",        "config/environments/test.rb"

      # Scripts
      %w( about console dbconsole destroy generate performance/benchmarker performance/profiler performance/request process/reaper process/spawner process/inspector runner server plugin ).each do |file|
        m.file "bin/#{file}", "script/#{file}", script_options
      end

      # Dispatches
      m.file "dispatches/dispatch.rb",   "public/dispatch.rb", dispatcher_options
      m.file "dispatches/dispatch.rb",   "public/dispatch.cgi", dispatcher_options
      m.file "dispatches/dispatch.fcgi", "public/dispatch.fcgi", dispatcher_options

      # HTML files
      %w(404 422 500 index).each do |file|
        m.template "html/#{file}.html", "public/#{file}.html"
      end

      m.template "html/favicon.ico",  "public/favicon.ico"
      m.template "html/robots.txt",   "public/robots.txt"
      m.file "html/images/rails.png", "public/images/rails.png"

      # Javascripts
      m.file "html/javascripts/prototype.js",    "public/javascripts/prototype.js"
      m.file "html/javascripts/effects.js",      "public/javascripts/effects.js"
      m.file "html/javascripts/dragdrop.js",     "public/javascripts/dragdrop.js"
      m.file "html/javascripts/controls.js",     "public/javascripts/controls.js"
      m.file "html/javascripts/application.js",  "public/javascripts/application.js"

      # Docs
      m.file "doc/README_FOR_APP", "doc/README_FOR_APP"

      # Logs
      %w(server production development test).each { |file|
        m.file "configs/empty.log", "log/#{file}.log", :chmod => 0666
      }
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

      opt.on("-f", "--freeze",
            "Freeze Rails in vendor/rails from the gems generating the skeleton",
            "Default: false") { |v| options[:freeze] = v }
    end

    def mysql_socket_location
      MYSQL_SOCKET_LOCATIONS.find { |f| File.exist?(f) } unless RUBY_PLATFORM =~ /(:?mswin|mingw)/
    end


  # Installation skeleton.  Intermediate directories are automatically
  # created so don't sweat their absence here.
  BASEDIRS = %w(
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
    script/process
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
  )

  MYSQL_SOCKET_LOCATIONS = [
    "/tmp/mysql.sock",                        # default
    "/var/run/mysqld/mysqld.sock",            # debian/gentoo
    "/var/tmp/mysql.sock",                    # freebsd
    "/var/lib/mysql/mysql.sock",              # fedora
    "/opt/local/lib/mysql/mysql.sock",        # fedora
    "/opt/local/var/run/mysqld/mysqld.sock",  # mac + darwinports + mysql
    "/opt/local/var/run/mysql4/mysqld.sock",  # mac + darwinports + mysql4
    "/opt/local/var/run/mysql5/mysqld.sock",  # mac + darwinports + mysql5
    "/opt/lampp/var/mysql/mysql.sock"         # xampp for linux
  ]
end
