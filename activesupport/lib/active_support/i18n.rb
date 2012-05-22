begin
  require 'i18n'
  require 'active_support/lazy_load_hooks'
rescue LoadError => e
  $stderr.puts "The i18n gem is not available. Please add it to your Gemfile and run bundle install"
  raise e
end

ActiveSupport.run_load_hooks(:i18n)
I18n.load_path << "#{File.dirname(__FILE__)}/locale/en.yml"
