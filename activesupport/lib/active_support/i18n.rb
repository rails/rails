require 'i18n'
I18n.load_path << "#{File.dirname(__FILE__)}/locale/en.yml"
ActiveSupport.run_load_hooks(:i18n)