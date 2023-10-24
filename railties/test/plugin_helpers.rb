# frozen_string_literal: true

module PluginHelpers
  def generate_plugin(plugin_path, *args)
    system(*%w[bundle exec rails plugin new], plugin_path, *args, out: File::NULL, exception: true)
    prepare_plugin(plugin_path)
  end

  def prepare_plugin(plugin_path)
    # Fill placeholders in gemspec to prevent Gem::InvalidSpecificationException
    # from being raised. (Some fields require a valid URL, so use one for all.)
    gemspec_path = "#{plugin_path}/#{File.basename(plugin_path)}.gemspec"
    gemspec = File.read(gemspec_path).gsub(/"TODO.*"/, "http://example.com".inspect)
    File.write(gemspec_path, gemspec)

    # Resolve `rails` gem to this repo so that Bundler doesn't search for a
    # version of Rails that hasn't been released yet.
    gemfile_path = "#{plugin_path}/Gemfile"
    gemfile = <<~RUBY
      #{File.read(gemfile_path).sub(/gem "rails".*/, "")}
      gem "rails", path: #{File.expand_path("../..", __dir__).inspect}
    RUBY
    File.write(gemfile_path, gemfile)

    # Make sure the plugin's dependencies are installed.
    in_plugin_context(plugin_path) { system(*%w[bundle install], out: File::NULL, exception: true) }
  end

  def in_plugin_context(plugin_path, &block)
    # Run with `Bundler.with_unbundled_env` so that Bundler uses the plugin's
    # Gemfile instead of this repo's Gemfile.
    delete_ci_env = -> do
      ENV.delete("CI") if ENV["BUILDKITE"]
      block.call
    end
    Dir.chdir(plugin_path) { Bundler.with_unbundled_env(&delete_ci_env) }
  end

  def with_new_plugin(plugin_path, *args, &block)
    generate_plugin(plugin_path, *args)
    in_plugin_context(plugin_path, &block)
  end
end
