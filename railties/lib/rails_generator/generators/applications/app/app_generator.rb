require 'rbconfig'

class AppGenerator < Rails::Generator::Base
  DEFAULT_SHEBANG = File.join(Config::CONFIG['bindir'],
                              Config::CONFIG['ruby_install_name'])
  
  default_options   :gem => true, :shebang => DEFAULT_SHEBANG
  mandatory_options :source  => "#{File.dirname(__FILE__)}/../../../../.."

  def initialize(runtime_args, runtime_options = {})
    super
    usage if args.empty?
    @destination_root = args.shift
    @socket = MYSQL_SOCKET_LOCATIONS.find { |f| File.exists?(f) }
    @socket = '/path/to/your/mysql.sock' if @socket.blank?
  end

  def manifest
    script_options     = { :chmod => 0755 }
    dispatcher_options = { :chmod => 0755, :shebang => options[:shebang] }

    record do |m|
      # Root directory and all subdirectories.
      m.directory ''
      BASEDIRS.each { |path| m.directory path }

      # Root
      m.file "fresh_rakefile", "Rakefile"
      m.file "README",         "README"

      # Application
      m.template "helpers/application.rb",        "app/controllers/application.rb"
      m.template "helpers/application_helper.rb", "app/helpers/application_helper.rb"
      m.template "helpers/test_helper.rb",        "test/test_helper.rb"

      # database.yml and .htaccess
      m.template "configs/database.yml", "config/database.yml", :assigns => {
        :app_name => File.basename(File.expand_path(@destination_root)),
        :socket => @socket
      }
      m.template "configs/routes.rb",     "config/routes.rb"
      m.template "configs/apache.conf",   "public/.htaccess"

      # Environments
      m.file "environments/boot.rb",        "config/boot.rb"
      m.file "environments/environment.rb", "config/environment.rb"
      m.file "environments/production.rb",  "config/environments/production.rb"
      m.file "environments/development.rb", "config/environments/development.rb"
      m.file "environments/test.rb",        "config/environments/test.rb"

      # Scripts
      %w( about breakpointer console destroy generate performance/benchmarker performance/profiler process/reaper process/spawner process/spinner runner server plugin ).each do |file|
        m.file "bin/#{file}", "script/#{file}", script_options
      end

      # Dispatches
      m.file "dispatches/dispatch.rb",   "public/dispatch.rb", dispatcher_options
      m.file "dispatches/dispatch.rb",   "public/dispatch.cgi", dispatcher_options
      m.file "dispatches/dispatch.fcgi", "public/dispatch.fcgi", dispatcher_options

      # HTML files
      %w(404 500 index).each do |file|
        m.template "html/#{file}.html", "public/#{file}.html"
      end
      
      m.template "html/favicon.ico", "public/favicon.ico"
      m.template "html/robots.txt", "public/robots.txt"
      m.file "html/images/rails.png", "public/images/rails.png"

      # Javascripts
      m.file "html/javascripts/prototype.js",     "public/javascripts/prototype.js"
      m.file "html/javascripts/effects.js",       "public/javascripts/effects.js"
      m.file "html/javascripts/dragdrop.js",      "public/javascripts/dragdrop.js"
      m.file "html/javascripts/controls.js",      "public/javascripts/controls.js"

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
      opt.on("--ruby [#{DEFAULT_SHEBANG}]",
             "Path to the Ruby binary of your choice.") { |options[:shebang]| }
      opt.on("--without-gems",
             "Don't use the Rails gems for your app.",
             "WARNING: see note below.") { |options[:gem]| }
    end


  # Installation skeleton.  Intermediate directories are automatically
  # created so don't sweat their absence here.
  BASEDIRS = %w(
    app/controllers
    app/helpers
    app/models
    app/views/layouts
    config/environments
    components
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
    test/mocks/development
    test/mocks/test
    test/unit
    vendor
    vendor/plugins
  )

  MYSQL_SOCKET_LOCATIONS = [
    "/tmp/mysql.sock",                        # default
    "/var/run/mysqld/mysqld.sock",            # debian/gentoo
    "/var/tmp/mysql.sock",                    # freebsd
    "/var/lib/mysql/mysql.sock",              # fedora
    "/opt/local/lib/mysql/mysql.sock",        # fedora
    "/opt/local/var/run/mysqld/mysqld.sock",  # mac + darwinports + mysql
    "/opt/local/var/run/mysql4/mysqld.sock",  # mac + darwinports + mysql4
    "/opt/local/var/run/mysql5/mysqld.sock"   # mac + darwinports + mysql5
  ]
end
