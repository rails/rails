require "pathname"

require 'active_support'
require 'active_support/core_ext/kernel/reporting'
require 'active_support/core_ext/logger'

require 'rails/initializable'
require 'rails/application'
require 'rails/railties_path'
require 'rails/version'
require 'rails/rack'
require 'rails/paths'
require 'rails/core'
require 'rails/configuration'
require 'rails/deprecation'
require 'rails/initializer'
require 'rails/plugin'
require 'rails/ruby_version_check'

# For Ruby 1.8, this initialization sets $KCODE to 'u' to enable the
# multibyte safe operations. Plugin authors supporting other encodings
# should override this behaviour and set the relevant +default_charset+
# on ActionController::Base.
#
# For Ruby 1.9, UTF-8 is the default internal and external encoding.
if RUBY_VERSION < '1.9'
  $KCODE='u'
else
  Encoding.default_external = Encoding::UTF_8
end

RAILS_ENV = (ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development").dup unless defined?(RAILS_ENV)