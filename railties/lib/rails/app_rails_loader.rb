require 'pathname'

module Rails
  module AppRailsLoader
    RUBY = File.join(*RbConfig::CONFIG.values_at("bindir", "ruby_install_name")) + RbConfig::CONFIG["EXEEXT"]
    EXECUTABLES = ['bin/rails', 'script/rails']

    def self.exec_app_rails
      cwd   = Dir.pwd

      exe   = find_executable
      exe ||= find_executable_in_parent_path
      return unless exe

      exec RUBY, exe, *ARGV if find_executable
      Dir.chdir("..") do
        # Recurse in a chdir block: if the search fails we want to be sure
        # the application is generated in the original working directory.
        exec_app_rails unless cwd == Dir.pwd
      end
    rescue SystemCallError
      # could not chdir, no problem just return
    end

    def self.find_executable
      EXECUTABLES.find do |exe|
        File.exists?(exe) && File.read(exe) =~ /(APP|ENGINE)_PATH/
      end
    end

    def self.find_executable_in_parent_path(path = Pathname.new(Dir.pwd))
      EXECUTABLES.find do |exe|
        File.exists?(File.join(path, exe)) || !path.root? && find_executable_in_parent_path(path.parent)
      end
    end
  end
end
