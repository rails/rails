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
  end

  def manifest
    script_options = { :chmod => 0755, :shebang => options[:shebang] }

    record do |m|
      # Root directory and all subdirectories.
      m.directory ''
      BASEDIRS.each { |path| m.directory path }

      # Root
      m.file "fresh_rakefile", "Rakefile"
      m.file "README",         "README"
      m.file "CHANGELOG",      "CHANGELOG"

      # Application
      m.template "helpers/application.rb",        "app/controllers/application.rb"
      m.template "helpers/application_helper.rb", "app/helpers/application_helper.rb"
      m.template "helpers/test_helper.rb",        "test/test_helper.rb"

      # database.yml and .htaccess
      m.template "configs/database.yml", "config/database.yml"
      m.template "configs/routes.rb",    "config/routes.rb"
      m.template "configs/apache.conf",  "public/.htaccess"

      # Environments
      m.file "environments/environment.rb", "config/environment.rb"
      m.file "environments/production.rb",  "config/environments/production.rb"
      m.file "environments/development.rb", "config/environments/development.rb"
      m.file "environments/test.rb",        "config/environments/test.rb"

      # Scripts (tracker listener)
      %w(console destroy generate server runner benchmarker profiler ).each do |file|
        m.file "bin/#{file}", "script/#{file}", script_options
      end
      if options[:gem]
        m.file "bin/breakpointer_for_gem", "script/breakpointer", script_options
      else
        m.file "bin/breakpointer", "script/breakpointer", script_options
      end

      # Dispatches
      m.file "dispatches/dispatch.rb",   "public/dispatch.rb", script_options
      m.file "dispatches/dispatch.rb",   "public/dispatch.cgi", script_options
      m.file "dispatches/dispatch.fcgi", "public/dispatch.fcgi", script_options
      # m.file "dispatches/gateway.cgi",   "public/gateway.cgi", script_options

      # HTML files
      %w(404 500 index).each do |file|
        m.template "html/#{file}.html", "public/#{file}.html"
      end
      
      m.template "html/favicon.ico", "public/favicon.ico"

      # Javascripts
      m.file "html/javascripts/prototype.js", "public/javascripts/prototype.js"
      m.file "html/javascripts/effects.js",   "public/javascripts/effects.js"
      m.file "html/javascripts/dragdrop.js",  "public/javascripts/dragdrop.js"
      m.file "html/javascripts/controls.js",  "public/javascripts/controls.js"

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
    app/apis
    app/controllers
    app/helpers
    app/models
    app/views/layouts
    config/environments
    components
    db
    doc
    lib
    log
    public/images
    public/javascripts
    public/stylesheets
    script
    test/fixtures
    test/functional
    test/mocks/development
    test/mocks/test
    test/unit
    vendor
  )
end
