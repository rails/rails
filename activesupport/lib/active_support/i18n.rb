require 'i18n'
I18n.load_path << "#{File.dirname(__FILE__)}/locale/en.yml"
ActiveSupport.run_base_hooks(:i18n)