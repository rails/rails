require 'rbconfig'

module Rails
  module ScriptRailsLoader
    RUBY = File.join(*RbConfig::CONFIG.values_at("bindir", "ruby_install_name")) + RbConfig::CONFIG["EXEEXT"]
    SCRIPT_RAILS = File.join('script', 'rails')

    def self.exec_script_rails!
      cwd = Dir.pwd
      exec RUBY, SCRIPT_RAILS, *ARGV if File.exists?(SCRIPT_RAILS)
      Dir.chdir("..") do
        # Recurse in a chdir block: if the search fails we want to be sure
        # the application is generated in the original working directory.
        exec_script_rails! unless cwd == Dir.pwd
      end
    rescue SystemCallError
      # could not chdir, no problem just return
    end
  end
end

Rails::ScriptRailsLoader.exec_script_rails!

railties_path = File.expand_path('../../lib', __FILE__)
$:.unshift(railties_path) if File.directory?(railties_path) && !$:.include?(railties_path)

require 'rails/ruby_version_check'
Signal.trap("INT") { puts; exit }

require 'rails/commands/application'
