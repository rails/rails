require 'active_support/testing/autorun'
require 'active_support/test_case'
require 'rbconfig'
require 'active_support/core_ext/kernel/reporting'

class TestIsolated < ActiveSupport::TestCase
  ruby = File.join(*RbConfig::CONFIG.values_at('bindir', 'RUBY_INSTALL_NAME'))

  Dir["#{File.dirname(__FILE__)}/**/*_test.rb"].each do |file|
    define_method("test #{file}") do
      command = "#{ruby} -Ilib:test #{file}"
      result = silence_stderr { `#{command}` }
      assert $?.to_i.zero?, "#{command}\n#{result}"
    end
  end
end
