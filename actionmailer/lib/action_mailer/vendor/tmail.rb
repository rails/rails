# Prefer gems to the bundled libs.
require 'rubygems'

begin
  gem 'tmail', '~> 1.2.3'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/tmail-1.2.3"
end

module TMail
end

require 'tmail'

require 'active_support/core_ext/kernel/reporting'
silence_warnings do
  TMail::Encoder.const_set("MAX_LINE_LEN", 200)
end
