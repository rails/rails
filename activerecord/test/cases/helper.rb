require File.expand_path('../../../../load_paths', __FILE__)

require 'config'

require 'active_support/testing/autorun'
require 'active_support/testing/method_call_assertions'
require 'stringio'

require 'active_record'
require 'cases/test_case'
require 'active_support/dependencies'
require 'active_support/logger'
require 'active_support/core_ext/string/strip'

require 'support/config'
require 'support/connection'
require 'support/setup'
