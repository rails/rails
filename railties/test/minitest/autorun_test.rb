# frozen_string_literal: true

require "abstract_unit"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

# autorun.rb is a top-level script that runs on require and calls
# Minitest.autorun, so it cannot be re-required in-process. That's why these
# tests run in a fresh subprocess and load autorun.rb.
class MinitestAutorunTest < ActiveSupport::TestCase
  test "requiring active_support/testing/autorun loads every minitest plugin on the load path, not only the Rails plugin" do
    extensions = extensions_from_autorun_subprocess(plugin: "zzz_extra")

    assert_includes extensions, "zzz_extra"
    assert_includes extensions, "rails"
  end

  test "requiring active_support/testing/autorun pins the Rails plugin to the tail of Minitest.extensions, registered once" do
    extensions = extensions_from_autorun_subprocess(plugin: "aaa_other")

    assert_equal "rails", extensions.last
    assert_equal 1, extensions.count("rails")
  end

  test "a third-party plugin defining the Rails -b/--backtrace flag does not clobber it when autorun pins Rails last" do
    plugin_source = <<~RUBY
      $fake_backtrace_called = false
      def Minitest.plugin_fake_backtrace_options(opts, options)
        opts.on("-b", "--backtrace", "fake") { $fake_backtrace_called = true }
      end
    RUBY
    after_require = <<~RUBY
      options = Minitest.process_args(%w[--backtrace --seed 12345])
      warn({ full_backtrace: !!options[:full_backtrace], fake_called: $fake_backtrace_called }.to_json)
    RUBY

    stdout, stderr = run_autorun_subprocess(plugin: "fake_backtrace", plugin_source: plugin_source, after_require: after_require)
    result = json_from_stderr(stderr) or flunk "subprocess produced no JSON. stderr=\n#{stderr}\nstdout=\n#{stdout}"

    assert result["full_backtrace"], "Rails -b/--backtrace handler did not run"
    assert_not result["fake_called"], "third-party -b/--backtrace handler clobbered Rails'"
  end

  private
    def extensions_from_autorun_subprocess(plugin:)
      stdout, stderr = run_autorun_subprocess(plugin: plugin)
      json_from_stderr(stderr) or flunk "subprocess produced no extensions JSON. stderr=\n#{stderr}\nstdout=\n#{stdout}"
    end

    # Requires active_support/testing/autorun in a fresh subprocess with
    # +plugin+ as a discoverable minitest plugin on the load path (its source
    # defaulting to an empty file), then evaluates +after_require+ in that
    # process. Returns [stdout, stderr]. The subprocess inherits the bundler
    # environment so the bundle's minitest is used.
    def run_autorun_subprocess(plugin:, plugin_source: "", after_require: "warn Minitest.extensions.to_json")
      Dir.mktmpdir("autorun-test") do |tmp|
        FileUtils.mkdir_p("#{tmp}/minitest")
        File.write("#{tmp}/minitest/#{plugin}_plugin.rb", plugin_source)
        script = <<~RUBY
          require "bundler/setup"
          $LOAD_PATH.unshift("#{tmp}")
          require "active_support/testing/autorun"
          require "json"
          #{after_require}
          # exit! skips Minitest's at_exit hook.
          exit!(true)
        RUBY

        stdout, stderr, _status = Open3.capture3("ruby", "-e", script)
        [stdout, stderr]
      end
    end

    def json_from_stderr(stderr)
      stderr.lines.map { |line| JSON.parse(line) rescue nil }.find { |parsed| parsed.is_a?(Hash) || parsed.is_a?(Array) }
    end
end
