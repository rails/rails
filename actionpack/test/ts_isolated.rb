require 'active_support/testing/autorun'
require 'rbconfig'
require 'abstract_unit'

class TestIsolated < ActiveSupport::TestCase
  ruby = File.join(*RbConfig::CONFIG.values_at('bindir', 'RUBY_INSTALL_NAME'))

  Dir["#{File.dirname(__FILE__)}/{abstract,controller,dispatch,template}/**/*_test.rb"].each do |file|
    define_method("test #{file}") do
      command = "#{ruby} -Ilib:test #{file}"
      result = silence_stderr { `#{command}` }
      assert $?.to_i.zero?, "#{command}\n#{result}"
    end
  end
end
