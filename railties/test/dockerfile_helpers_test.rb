# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"
require "rails/dockerfile_helpers"

class DockerfileHelpersTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  include EnvHelpers

  setup :build_app
  teardown :teardown_app

  test "#gem? returns true when the gem is used in the current environment" do
    with_rails_env "development" do
      assert helpers.gem?("web-console")

      assert helpers.gem?("actionpack")
      assert_not helpers.gem?("some_missing_gem")
    end
  end

  test "#gem? returns false when the gem is not used in the current environment" do
    with_rails_env "production" do
      assert_not helpers.gem?("web-console")

      assert helpers.gem?("actionpack")
      assert_not helpers.gem?("some_missing_gem")
    end
  end


  test "#node? returns true when Node.js is required" do
    app_file "package.json", "{}"
    assert_predicate helpers, :node?
  end

  test "#node? returns false when Node.js is not required" do
    remove_file "package.json"
    assert_not_predicate helpers, :node?
  end


  test "#ruby_version returns a string suitable for use with the Ruby slim Docker image" do
    Gem.stub(:ruby_version, Gem::Version.new("1.2.3")) do
      assert_equal "1.2.3", helpers.ruby_version
    end

    Gem.stub(:ruby_version, Gem::Version.new("1.2.3.preview1")) do
      assert_equal "1.2.3-preview1", helpers.ruby_version
    end
  end

  # test "#node_version"
  # test "#yarn_version"

  test "#render re-uses the current rendering context" do
    app_file "template.erb", %(<% @foo = "stuff" %><%= render "other.erb" %>)
    app_file "other.erb", %(<%= @foo.upcase %>)

    assert_match %r/\ASTUFF/, helpers.render("template.erb")
  end

  test "#render considers template path relative to the app root" do
    app_file "config/template.erb", %(<%= render "my/other/template.erb" %>)
    app_file "my/other/template.erb", %(<%= "stuff".upcase %>)

    assert_match %r/\ASTUFF/, helpers.render("config/template.erb")
  end

  test "#install_packages includes command that installs the specified packages" do
    assert_match "apt-get install -y bar baz foo", helpers.install_packages(%w[foo bar], "baz")
  end

  test "#install_packages includes --no-install-recommends option when requested" do
    assert_match %r/ --no-install-recommends .*foo/, helpers.install_packages("foo", skip_recommends: true)
  end


  test "#install_gems includes Bootsnap precompile command when using Bootsnap" do
    add_gem "bootsnap"
    assert_match "bootsnap precompile --gemfile", helpers.install_gems
  end

  test "#install_gems does not include Bootsnap command when not using Bootsnap" do
    remove_gem "bootsnap"
    assert_no_match "bootsnap", helpers.install_gems
  end


  test "#prepare_app includes Bootsnap precompile command when using Bootsnap" do
    add_gem "bootsnap"
    assert_match "bootsnap precompile app/ lib/", helpers.prepare_app
  end

  test "#prepare_app does not include Bootsnap command when not using Bootsnap" do
    remove_gem "bootsnap"
    assert_no_match "bootsnap", helpers.prepare_app
  end

  test "#prepare_app includes binstubs:change command when applicable" do
    helpers.stub(:windows?, true) do
      assert_match "rails binstubs:change", helpers.prepare_app
      assert_no_match "rails binstubs:change", helpers.prepare_app(change_binstubs: false)
    end

    helpers.stub(:windows?, false) do
      assert_no_match "rails binstubs:change", helpers.prepare_app
      assert_match "rails binstubs:change", helpers.prepare_app(change_binstubs: true)
    end
  end

  test "#prepare_app includes assets:precompile command when applicable" do
    helpers.stub(:api_only?, false) do
      assert_match "rails assets:precompile", helpers.prepare_app
      assert_no_match "rails assets:precompile", helpers.prepare_app(precompile_assets: false)
    end

    helpers.stub(:api_only?, true) do
      assert_no_match "rails assets:precompile", helpers.prepare_app
      assert_match "rails assets:precompile", helpers.prepare_app(precompile_assets: true)
    end
  end

  test "#prepare_app includes additional commands when specified" do
    assert_match %r/&&[\s\\]+foo bar &&[\s\\]+baz qux/, helpers.prepare_app("foo bar", "baz qux")
  end


  test "#runtime_packages includes runtime packages for gems in the current group" do
    add_gem "pg", group: :production

    with_rails_env "production" do
      assert_packages runtime("pg"), helpers.runtime_packages
      assert_not_packages buildtime("pg"), helpers.runtime_packages

      assert_not_packages runtime("mysql2") - runtime("pg"), helpers.runtime_packages
    end
  end

  test "#runtime_packages does not include packages for gems not in the current group" do
    add_gem "pg", group: :production

    with_rails_env "development" do
      assert_not_packages runtime("pg"), helpers.runtime_packages
      assert_not_packages buildtime("pg"), helpers.runtime_packages
    end
  end


  test "#buildtime_packages includes build packages for gems in the current group" do
    add_gem "pg", group: :production

    with_rails_env "production" do
      assert_packages buildtime("pg"), helpers.buildtime_packages
      assert_not_packages runtime("pg"), helpers.buildtime_packages

      assert_not_packages buildtime("mysql2") - buildtime("pg"), helpers.buildtime_packages
    end
  end

  test "#buildtime_packages does not include packages for gems not in the current group" do
    add_gem "pg", group: :production

    with_rails_env "development" do
      assert_not_packages buildtime("pg"), helpers.buildtime_packages
      assert_not_packages runtime("pg"), helpers.buildtime_packages
    end
  end

  test "#buildtime_packages includes Node.js packages when applicable" do
    helpers.stub(:node?, true) do
      assert_packages "node-gyp", helpers.buildtime_packages
      assert_not_packages "node-gyp", helpers.buildtime_packages(node: false)
    end

    helpers.stub(:node?, false) do
      assert_not_packages "node-gyp", helpers.buildtime_packages
      assert_packages "node-gyp", helpers.buildtime_packages(node: true)
    end
  end

  test "#buildtime_packages includes essential packages" do
    assert_packages "build-essential", helpers.buildtime_packages
  end

  test "gem groups passed to Bundler.require are acknowledged by helpers" do
    # Prevent actually calling `Bundler.require` by intercepting
    # `RequiredGemGroupsTracker#require`'s call to `super`. Can't do this in
    # Ruby 2.7 because `Module#prepend` behaves differently.
    skip if RUBY_VERSION < "3.0"
    Rails::DockerfileHelpers::RequiredGemGroupsTracker.include(Module.new do
      def require(...); end
    end)

    add_gem "pg", group: :some_group
    add_gem "mysql2", group: :some_other_group
    app_file "config/application.rb", <<~RUBY, "a"
      Bundler.require(*Rails.groups(some_group: [:production]))
    RUBY

    with_rails_env "production" do
      assert helpers.gem?("pg")
      assert_packages runtime("pg"), helpers.runtime_packages
      assert_packages buildtime("pg"), helpers.buildtime_packages

      assert_not helpers.gem?("mysql2")
    end
  end

  private
    def helpers
      @helpers ||= begin
        Bundler.reset_paths!
        Bundler.ui.level = "silent"
        ENV["BUNDLE_GEMFILE"] = app_path("Gemfile")
        quietly { require "#{app_path}/config/environment" }
        Object.new.extend(Rails::DockerfileHelpers)
      end
    end

    def runtime(gem)
      Rails::DockerfileHelpers::GEM_RUNTIME_PACKAGES.fetch(gem)
    end

    def buildtime(gem)
      Rails::DockerfileHelpers::GEM_BUILDTIME_PACKAGES.fetch(gem)
    end

    def assert_packages(expected, actual)
      Array(expected).each { |package| assert_includes actual, package }
    end

    def assert_not_packages(unexpected, actual)
      Array(unexpected).each { |package| assert_not_includes actual, package }
    end

    def add_gem(gem, group: nil)
      statement = "gem #{gem.inspect}"
      statement = "group(#{group.inspect}) { #{statement} }" if group
      app_file "Gemfile", "#{statement}\n", "a"
    end

    def remove_gem(gem)
      remove_from_file app_path("Gemfile"), /^gem #{gem.inspect}.*/
    end
end
