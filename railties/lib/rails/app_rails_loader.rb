require 'pathname'

module Rails
  module AppRailsLoader
    RUBY = File.join(*RbConfig::CONFIG.values_at("bindir", "ruby_install_name")) + RbConfig::CONFIG["EXEEXT"]
    EXECUTABLE = 'bin/rails'

    def self.exec_app_rails
      cwd = Dir.pwd
      return unless in_rails_application_or_engine? || in_rails_application_or_engine_subdirectory?
      exec RUBY, EXECUTABLE, *ARGV if in_rails_application_or_engine?
      Dir.chdir("..") do
        # Recurse in a chdir block: if the search fails we want to be sure
        # the application is generated in the original working directory.
        exec_app_rails unless cwd == Dir.pwd
      end
    rescue SystemCallError
      # could not chdir, no problem just return
    end

    def self.in_rails_application_or_engine?
      File.exists?(EXECUTABLE) && File.read(EXECUTABLE) =~ /(APP|ENGINE)_PATH/
    end

    def self.in_rails_application_or_engine_subdirectory?(path = Pathname.new(Dir.pwd))
      File.exists?(File.join(path, EXECUTABLE)) || !path.root? && in_rails_application_or_engine_subdirectory?(path.parent)
    end
  end
end
