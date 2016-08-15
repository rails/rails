#
# Tests, setup, and teardown common to the application and plugin generator suites.
#
module SharedGeneratorTests
  def setup
    Rails.application = TestApp::Application
    super
    Rails::Generators::AppGenerator.instance_variable_set("@desc", nil)

    Kernel::silence_warnings do
      Thor::Base.shell.send(:attr_accessor, :always_force)
      @shell = Thor::Base.shell.new
      @shell.send(:always_force=, true)
    end
  end

  def teardown
    super
    Rails::Generators::AppGenerator.instance_variable_set("@desc", nil)
    Rails.application = TestApp::Application.instance
  end

  def test_skeleton_is_created
    run_generator

    default_files.each { |path| assert_file path }
  end

  def test_plugin_new_generate_pretend
    run_generator ["testapp", "--pretend"]
    default_files.each{ |path| assert_no_file File.join("testapp",path) }
  end

  def test_invalid_database_option_raises_an_error
    content = capture(:stderr){ run_generator([destination_root, "-d", "unknown"]) }
    assert_match(/Invalid value for \-\-database option/, content)
  end

  def test_test_files_are_skipped_if_required
    run_generator [destination_root, "--skip-test"]
    assert_no_file "test"
  end

  def test_name_collision_raises_an_error
    reserved_words = %w[application destroy plugin runner test]
    reserved_words.each do |reserved|
      content = capture(:stderr){ run_generator [File.join(destination_root, reserved)] }
      assert_match(/Invalid \w+ name #{reserved}. Please give a name which does not match one of the reserved rails words: application, destroy, plugin, runner, test\n/, content)
    end
  end

  def test_name_raises_an_error_if_name_already_used_constant
    %w{ String Hash Class Module Set Symbol }.each do |ruby_class|
      content = capture(:stderr){ run_generator [File.join(destination_root, ruby_class)] }
      assert_match(/Invalid \w+ name #{ruby_class}, constant #{ruby_class} is already in use. Please choose another \w+ name.\n/, content)
    end
  end

  def test_shebang_is_added_to_rails_file
    run_generator [destination_root, "--ruby", "foo/bar/baz", "--full"]
    assert_file "bin/rails", /#!foo\/bar\/baz/
  end

  def test_shebang_when_is_the_same_as_default_use_env
    run_generator [destination_root, "--ruby", Thor::Util.ruby_command, "--full"]
    assert_file "bin/rails", /#!\/usr\/bin\/env/
  end

  def test_template_raises_an_error_with_invalid_path
    quietly do
      content = capture(:stderr){ run_generator([destination_root, "-m", "non/existent/path"]) }

      assert_match(/The template \[.*\] could not be loaded/, content)
      assert_match(/non\/existent\/path/, content)
    end
  end

  def test_template_is_executed_when_supplied_an_https_path
    path = "https://gist.github.com/josevalim/103208/raw/"
    template = %{ say "It works!" }
    template.instance_eval "def read; self; end" # Make the string respond to read

    check_open = -> *args do
      assert_equal [ path, "Accept" => "application/x-thor-template" ], args
      template
    end

    generator([destination_root], template: path).stub(:open, check_open, template) do
      quietly { assert_match(/It works!/, capture(:stdout) { generator.invoke_all }) }
    end
  end

  def test_skip_gemfile
    assert_not_called(generator([destination_root], skip_gemfile: true), :bundle_command) do
      quietly { generator.invoke_all }
      assert_no_file "Gemfile"
    end
  end

  def test_skip_bundle
    assert_not_called(generator([destination_root], skip_bundle: true), :bundle_command) do
      quietly { generator.invoke_all }
      # skip_bundle is only about running bundle install, ensure the Gemfile is still
      # generated.
      assert_file "Gemfile"
    end
  end

  def test_skip_git
    run_generator [destination_root, "--skip-git", "--full"]
    assert_no_file(".gitignore")
  end

  def test_skip_keeps
    run_generator [destination_root, "--skip-keeps", "--full"]

    assert_file ".gitignore" do |content|
      assert_no_match(/\.keep/, content)
    end

    assert_no_file("app/models/concerns/.keep")
  end
end
