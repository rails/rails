require 'rbconfig'

class App < Thor::Group
  include Thor::Actions

  def self.source_root
    @source_root ||= File.join(File.dirname(__FILE__), '..', 'templates', 'app')
  end

  DEFAULT_SHEBANG  = File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])
  DATABASES        = %w( mysql oracle postgresql sqlite2 sqlite3 frontbase ibm_db )
  DEFAULT_DATABASE = 'sqlite3'

  argument :app_path, :type => :string

  class_option :ruby, :type => :string, :aliases => "-d", :default => DEFAULT_SHEBANG,
                      :desc => "Path to the Ruby binary of your choice"

  class_option :database, :type => :string, :aliases => "-d", :default => DEFAULT_DATABASE,
                          :desc => "Preconfigure for selected database (options: #{DATABASES.join('/')})"

  class_option :with_dispatchers, :type => :boolean, :aliases => "-D", :default => false,
                                  :desc => "Add CGI/FastCGI/mod_ruby dispatches code"

  class_option :freeze, :type => :boolean, :aliases => "-f", :default => false,
                        :desc => "Freeze Rails in vendor/rails from the gems"

  class_option :template, :type => :string, :aliases => "-m",
                          :desc => "Use an application template that lives at path (can be a filesystem path or URL)."

  def create_root
    self.root = File.expand_path(app_path, root)
    empty_directory '.'

    app_name # Sets the app name
    FileUtils.cd(root)
  end

  def create_root_files
    copy_file "Rakefile"
    copy_file "README"
  end

  def create_app_files
    directory "app"
  end

  def create_doc_files
    directory "doc"
  end

  def create_log_files
    empty_directory "log"

    inside "log" do
      %w( server production development test ).each do |file|
        create_file "#{file}.log"
        chmod "#{file}.log", 0666, false
      end
    end
  end

#  def directories
#    %w(
#      config/environments
#      config/initializers
#      config/locales
#      db
#      lib
#      lib/tasks
#      public/images
#      public/javascripts
#      public/stylesheets
#      script/performance
#      test/fixtures
#      test/functional
#      test/integration
#      test/performance
#      test/unit
#      vendor
#      vendor/plugins
#      tmp/sessions
#      tmp/sockets
#      tmp/cache
#      tmp/pids
#    ).each { |path| empty_directory(path) }
#  end

  protected

    def app_name
      @app_name ||= File.basename(root)
    end
end
