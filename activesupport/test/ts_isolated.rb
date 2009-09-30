require 'test/unit'
require 'rbconfig'
require 'active_support/core_ext/kernel/reporting'

class TestIsolated < Test::Unit::TestCase
  ruby = File.join(*RbConfig::CONFIG.values_at('bindir', 'RUBY_INSTALL_NAME'))

  Dir["#{File.dirname(__FILE__)}/**/*_test.rb"].each do |file|
    define_method("test #{file}") do
      command = "#{ruby} -Ilib:test #{file}"
      silence_stderr { `#{command}` }
      assert_equal 0, $?.to_i, command
    end
  end
end
