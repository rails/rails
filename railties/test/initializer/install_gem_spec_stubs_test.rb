require "initializer/test_helper"

module InitializerTests
  class GemSpecStubsTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      $stderr = StringIO.new
    end

    test "user has an old boot.rb (defined by having no Rails.vendor_rails?)" do
      class << Rails
        undef vendor_rails?
      end

      assert_stderr(/outdated/) do
        assert_raises(SystemExit) do
          Rails::Initializer.run { |c| c.frameworks = [] }
        end
      end
    end

    test "requires rubygems" do
      Kernel.module_eval do
        alias old_require require
        def require(name)
          $rubygems_required = true if name == "rubygems"
          old_require(name)
        end
      end

      Rails.vendor_rails = true
      Rails::Initializer.run { |c| c.frameworks = [] }
      assert $rubygems_required
    end

    # Pending until we're further along
    # test "does not fail if rubygems does not exist" do
    #   Kernel.module_eval do
    #     alias old_require require
    #     def require(name)
    #       raise LoadError if name == "rubygems"
    #       old_require(name)
    #     end
    #   end
    #
    #   assert_nothing_raised do
    #     Rails::Initializer.run { |c| c.frameworks = [] }
    #   end
    # end

    test "adds fake Rubygems stubs if a framework is not loaded in Rubygems and we've vendored" do
      Rails.vendor_rails = true

      Rails::Initializer.run { |c| c.frameworks = [] }

      %w(rails activesupport activerecord actionpack actionmailer activeresource).each do |stub|
        gem_spec = Gem.loaded_specs[stub]
        assert_equal Gem::Version.new(Rails::VERSION::STRING), gem_spec.version
        assert_equal stub, gem_spec.name
        assert_equal "", gem_spec.loaded_from
      end
    end

    test "doesn't replace gem specs that are already loaded" do
      Rails.vendor_rails = true

      Gem.loaded_specs["rails"] = Gem::Specification.new do |s|
        s.name = "rails"
        s.version = Rails::VERSION::STRING
        s.loaded_from = "/foo/bar/baz"
      end

      Rails::Initializer.run { |c| c.frameworks = [] }

      assert_equal "/foo/bar/baz", Gem.loaded_specs["rails"].loaded_from

      %w(activesupport activerecord actionpack actionmailer activeresource).each do |stub|
        gem_spec = Gem.loaded_specs[stub]
        assert_equal Gem::Version.new(Rails::VERSION::STRING), gem_spec.version
        assert_equal stub, gem_spec.name
        assert_equal "", gem_spec.loaded_from
      end
    end
  end
end