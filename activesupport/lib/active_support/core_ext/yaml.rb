begin
  require 'psych'
  require 'active_support/core_ext/yaml/psych_visitors'

  YAML::ENGINE.yamler = 'psych'
rescue LoadError
  require 'yaml'
end
