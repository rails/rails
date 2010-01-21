# encoding: utf-8

$:.unshift File.expand_path("../lib", File.dirname(__FILE__))
$:.unshift File.expand_path(File.dirname(__FILE__))

require 'i18n'
require 'i18n/core_ext/object/meta_class'

require 'rubygems'
require 'test/unit'
require 'time'
require 'yaml'

begin
  require 'mocha'
rescue LoadError
  puts "skipping tests using mocha as mocha can't be found"
end


Dir[File.dirname(__FILE__) + '/api/**/*.rb'].each do |filename|
  require filename
end

$KCODE = 'u' unless RUBY_VERSION >= '1.9'

# wtf is wrong with this, why's there Kernel#test?
# class Module
#   def self.test(name, &block)
#     define_method("test: " + name, &block)
#   end
# end

class Test::Unit::TestCase
  def self.test(name, &block)
    define_method("test: " + name, &block)
  end

  def self.with_mocha
    yield if Object.respond_to?(:expects)
  end

  def teardown
    I18n.locale = nil
    I18n.default_locale = :en
    I18n.load_path = []
    I18n.available_locales = nil
    I18n.backend = nil
  end

  def translations
    I18n.backend.instance_variable_get(:@translations)
  end

  def store_translations(*args)
    data   = args.pop
    locale = args.pop || :en
    I18n.backend.store_translations(locale, data)
  end

  def locales_dir
    File.dirname(__FILE__) + '/fixtures/locales'
  end

  def euc_jp(string)
    string.encode!(Encoding::EUC_JP)
  end

  def can_store_procs?
    I18n::Backend::ActiveRecord === I18n.backend and
    I18n::Backend::ActiveRecord.included_modules.include?(I18n::Backend::ActiveRecord::StoreProcs)
  end
end

def setup_active_record
  begin
    require 'activerecord'
    require 'i18n/backend/active_record'
    require 'i18n/backend/active_record/store_procs'

    if I18n::Backend::Simple.method_defined?(:interpolate_with_deprecated_syntax)
      I18n::Backend::Simple.send(:remove_method, :interpolate) rescue NameError
    end

    ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Schema.define(:version => 1) do
      create_table :translations do |t|
        t.string :locale
        t.string :key
        t.string :value
        t.string :interpolations
        t.boolean :is_proc, :default => false
      end
    end

  rescue LoadError
    puts "skipping tests using activerecord as activerecord can't be found"
  end
end
