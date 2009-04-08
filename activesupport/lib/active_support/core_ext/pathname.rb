if defined? Pathname
  require 'active_support/core_ext/pathname/clean_within'
else
  autoload :Pathname, 'active_support/core_ext/pathname/clean_within'
end
