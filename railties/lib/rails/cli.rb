require 'rails/app_loader'

Rails::AppLoader.exec_app

require 'rails/ruby_version_check'
Signal.trap("INT") { puts; exit(1) }

if ARGV.first == 'plugin'
  ARGV.shift
  require 'rails/commands/plugin'
else
  require 'rails/commands/application'
end
