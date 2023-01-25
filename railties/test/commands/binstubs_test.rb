# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"
require "rails/commands/notes/notes_command"

class Rails::Command::BinstubsTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "binstubs:change can be run using the global rails command" do
    original_content = read_file("bin/rails")
    remove_file "bin/rails"
    windows_content = original_content.sub(/\A(#!.*ruby)$/, '\1.exe').gsub("\n", "\r\n")
    app_file "bin/rails", windows_content

    assert_match %r/\A#!.*ruby\.exe/, windows_content
    assert_match "\r", windows_content
    assert_not File.executable?(app_path("bin/rails"))

    Dir.chdir(app_path) do
      quietly do
        system("#{Gem.ruby} #{RAILS_FRAMEWORK_ROOT}/railties/exe/rails binstubs:change", exception: true)
      end
    end

    assert_equal original_content, read_file("bin/rails")
    assert File.executable?(app_path("bin/rails"))
  end

  test "binstubs:change without args changes all binstubs in bin/ (recursively)" do
    create_windows_binstubs "bin/foo", "bin/bar/baz"

    run_change_command

    assert_binstub "bin/foo"
    assert_binstub "bin/bar/baz"
  end

  test "binstubs:change can target a specified file" do
    create_windows_binstubs "foo", "bin/foo"

    assert_no_changes -> { read_file "bin/foo" } do
      run_change_command "foo"
    end

    assert_binstub "foo"
  end

  test "binstubs:change can target a specified directory" do
    create_windows_binstubs "dir/foo", "bin/foo"

    assert_no_changes -> { read_file "bin/foo" } do
      run_change_command "dir"
    end

    assert_binstub "dir/foo"
  end

  test "binstubs:change can target multiple specified files and directories" do
    create_windows_binstubs "bin/foo", "bin/subdir/foo", "bin/other"

    assert_no_changes -> { read_file "bin/other" } do
      run_change_command "bin/foo", "bin/subdir"
    end

    assert_binstub "bin/foo"
    assert_binstub "bin/subdir/foo"
  end

  test "binstubs:change does not replace non-Ruby shebangs by default" do
    create_windows_binstubs "bin/foo", interpreter: "rooby"

    run_change_command

    assert_binstub "bin/foo", interpreter: "rooby"
  end

  test "binstubs:change --pattern specifies the pattern to match for shebang replacement" do
    create_windows_binstubs "bin/foo", interpreter: "rooby"

    run_change_command pattern: "r[ou]+by"

    assert_binstub "bin/foo"
  end

  test "binstubs:change --interpreter specifies the desired interpreter for shebang replacement" do
    create_windows_binstubs "bin/foo"

    run_change_command interpreter: "rooby"

    assert_binstub "bin/foo", interpreter: "rooby"
  end

  test "binstubs:change ignores non-shebang files" do
    content = binstub("bin/foo", line_endings: "\r\n").delete_prefix("#")
    app_file "bin/foo", content

    run_change_command

    assert_equal content, read_file("bin/foo")
    assert_not File.executable?(app_path("bin/foo"))
  end

  private
    DEFAULT_INTERPRETER = "/usr/bin/env ruby"

    def run_change_command(*args, pattern: nil, interpreter: nil)
      args.push("--pattern", pattern) if pattern
      args.push("--interpreter", interpreter) if interpreter

      # Use #rails helper method because it's much faster than launching a new
      # process for each call.
      rails "binstubs:change", args
    end

    def binstub(path, interpreter: DEFAULT_INTERPRETER, line_endings: "\n")
      ["#!#{interpreter}", "", "# #{path}", ""].join(line_endings)
    end

    def create_binstubs(*paths, permission: true, **binstub_options)
      paths.each do |path|
        app_file path, binstub(path, **binstub_options)
        File.chmod(app_path(path), 0755) if permission
      end
    end

    def create_windows_binstubs(*paths, **binstub_options)
      create_binstubs(
        *paths,
        interpreter: DEFAULT_INTERPRETER + ".exe",
        line_endings: "\r\n",
        **binstub_options,
        permission: false,
      )
    end

    def read_file(relative)
      File.read(app_path(relative))
    end

    def assert_binstub(path, **binstub_options)
      assert_equal binstub(path, **binstub_options), read_file(path)
      assert File.executable?(app_path(path))
    end
end
