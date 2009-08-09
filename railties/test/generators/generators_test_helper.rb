require 'test/unit'
require 'fileutils'

fixtures = File.expand_path(File.join(File.dirname(__FILE__), '..', 'fixtures'))
if defined?(RAILS_ROOT)
  RAILS_ROOT.replace fixtures
else
  RAILS_ROOT = fixtures
end

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../../activerecord/lib"
$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../lib"
require 'generators'

CURRENT_PATH = File.expand_path(Dir.pwd)
Rails::Generators.no_color!

class GeneratorsTestCase < Test::Unit::TestCase
  include FileUtils

  def destination_root
    @destination_root ||= File.expand_path(File.join(File.dirname(__FILE__), 
                                            '..', 'fixtures', 'tmp'))
  end

  def setup
    cd CURRENT_PATH
    rm_rf(destination_root)
    mkdir_p(destination_root)
  end

  def test_truth
    # don't complain, test/unit
  end

  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure 
      eval("$#{stream} = #{stream.upcase}")
    end

    result
  end
  alias :silence :capture

  def assert_file(relative, *contents)
    absolute = File.join(destination_root, relative)
    assert File.exists?(absolute), "Expected file #{relative.inspect} to exist, but does not"

    read = File.read(absolute) if block_given? || !contents.empty?
    yield read if block_given?

    contents.each do |content|
      case content
        when String
          assert_equal content, read
        when Regexp
          assert_match content, read
      end
    end
  end

  def assert_no_file(relative)
    absolute = File.join(destination_root, relative)
    assert !File.exists?(absolute), "Expected file #{relative.inspect} to not exist, but does"
  end

  def assert_migration(relative, *contents, &block)
    file_name = migration_file_name(relative)
    assert file_name, "Expected migration #{relative} to exist, but was not found"
    assert_file File.join(File.dirname(relative), file_name), *contents, &block
  end

  def assert_no_migration(relative)
    file_name = migration_file_name(relative)
    assert_nil file_name, "Expected migration #{relative} to not exist, but found #{file_name}"
  end

  def assert_class_method(content, method, &block)
    assert_instance_method content, "self.#{method}", &block
  end

  def assert_instance_method(content, method)
    assert content =~ /def #{method}(\(.+\))?(.*?)\n  end/m, "Expected to have method #{method}"
    yield $2.strip if block_given?
  end

  protected

    def migration_file_name(relative)
      absolute = File.join(destination_root, relative)
      dirname, file_name = File.dirname(absolute), File.basename(absolute).sub(/\.rb$/, '')

      migration = Dir.glob("#{dirname}/[0-9]*_*.rb").grep(/\d+_#{file_name}.rb$/).first
      File.basename(migration) if migration
    end
end
