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

      if File.read(exe) =~ /(APP|ENGINE)_PATH/
        # This is a Rails-generated binstub, let's use it
        exec RUBY, exe, *ARGV if find_executable
        Dir.chdir("..") do
          # Recurse in a chdir block: if the search fails we want to be sure
          # the application is generated in the original working directory.
          exec_app_rails unless cwd == Dir.pwd
        end
      elsif exe.match(%r(bin/rails$))
        # this is a Bundler binstub, so we load the app ourselves
        Object.const_set(:APP_PATH, File.expand_path('config/application',  Dir.pwd))
        require File.expand_path('../boot', APP_PATH)
        puts "Rails 4 no longer supports Bundler's --binstubs option. You " \
          "will need to disable it and update your bin/rails file.\n" \
          "Please run: `bundle config --delete bin && rm -rf bin`, then " \
          "`rake rails:update:bin` and add the resulting bin/ to git."
        require 'rails/commands'
      end
    rescue SystemCallError
      # could not chdir, no problem just return
    end

    def self.find_executable
      EXECUTABLES.find { |exe| File.exists?(exe) }
    end

    def self.find_executable_in_parent_path(path = Pathname.new(Dir.pwd).parent)
      EXECUTABLES.find do |exe|
        File.exists?(exe) || !path.root? && find_executable_in_parent_path(path.parent)
      end
    end
  end
end
