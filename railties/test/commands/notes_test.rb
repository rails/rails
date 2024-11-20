# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"

class Rails::Command::NotesTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "`rails notes` displays results for default directories and default annotations with aligned line number and annotation tag" do
    app_file "app/controllers/some_controller.rb", "# OPTIMIZE: note in app directory"
    app_file "config/initializers/some_initializer.rb", "# TODO: note in config directory"
    app_file "db/some_seeds.rb", "# FIXME: note in db directory"
    app_file "lib/some_file.rb", "# TODO: note in lib directory"
    app_file "test/some_test.rb", "\n" * 100 + "# FIXME: note in test directory"

    app_file "some_other_dir/blah.rb", "# TODO: note in some_other directory"

    assert_equal <<~OUTPUT, run_notes_command
      app/controllers/some_controller.rb:
        * [  1] [OPTIMIZE] note in app directory

      config/initializers/some_initializer.rb:
        * [  1] [TODO] note in config directory

      db/some_seeds.rb:
        * [  1] [FIXME] note in db directory

      lib/some_file.rb:
        * [  1] [TODO] note in lib directory

      test/some_test.rb:
        * [101] [FIXME] note in test directory

    OUTPUT
  end

  test "`rails notes` displays an empty string when no results were found" do
    assert_equal "", run_notes_command
  end

  test "`rails notes --annotations` displays results for a single annotation without being prefixed by a tag" do
    app_file "db/some_seeds.rb", "# FIXME: note in db directory"
    app_file "test/some_test.rb", "# FIXME: note in test directory"

    app_file "app/controllers/some_controller.rb", "# OPTIMIZE: note in app directory"
    app_file "config/initializers/some_initializer.rb", "# TODO: note in config directory"

    assert_equal <<~OUTPUT, run_notes_command(["--annotations", "FIXME"])
      db/some_seeds.rb:
        * [1] note in db directory

      test/some_test.rb:
        * [1] note in test directory

    OUTPUT
  end

  test "`rails notes --annotations` displays results for multiple annotations being prefixed by a tag" do
    app_file "app/controllers/some_controller.rb", "# FOOBAR: note in app directory"
    app_file "config/initializers/some_initializer.rb", "# TODO: note in config directory"
    app_file "lib/some_file.rb", "# TODO: note in lib directory"

    app_file "test/some_test.rb", "# FIXME: note in test directory"

    assert_equal <<~OUTPUT, run_notes_command(["--annotations", "FOOBAR", "TODO"])
      app/controllers/some_controller.rb:
        * [1] [FOOBAR] note in app directory

      config/initializers/some_initializer.rb:
        * [1] [TODO] note in config directory

      lib/some_file.rb:
        * [1] [TODO] note in lib directory

    OUTPUT
  end

  test "displays results from additional directories added to the default directories from a config file" do
    app_file "db/some_seeds.rb", "# FIXME: note in db directory"
    app_file "lib/some_file.rb", "# TODO: note in lib directory"
    app_file "spec/spec_helper.rb", "# TODO: note in spec"
    app_file "spec/models/user_spec.rb", "# TODO: note in model spec"

    add_to_config "config.annotations.register_directories \"spec\""

    assert_equal <<~OUTPUT, run_notes_command
      db/some_seeds.rb:
        * [1] [FIXME] note in db directory

      lib/some_file.rb:
        * [1] [TODO] note in lib directory

      spec/models/user_spec.rb:
        * [1] [TODO] note in model spec

      spec/spec_helper.rb:
        * [1] [TODO] note in spec

    OUTPUT
  end

  test "displays results from additional file extensions added to the default extensions from a config file" do
    add_to_config "config.assets.precompile = []"
    add_to_config %q{ config.annotations.register_extensions("scss", "sass") { |annotation| /\/\/\s*(#{annotation}):?\s*(.*)$/ } }
    app_file "db/some_seeds.rb", "# FIXME: note in db directory"
    app_file "app/assets/stylesheets/application.css.scss", "// TODO: note in scss"
    app_file "app/assets/stylesheets/application.css.sass", "// TODO: note in sass"

    assert_equal <<~OUTPUT, run_notes_command
      app/assets/stylesheets/application.css.sass:
        * [1] [TODO] note in sass

      app/assets/stylesheets/application.css.scss:
        * [1] [TODO] note in scss

      db/some_seeds.rb:
        * [1] [FIXME] note in db directory

    OUTPUT
  end

  test "displays results from additional tags added to the default tags from a config file" do
    app_file "app/models/profile.rb", "# TESTME: some method to test"
    app_file "app/controllers/hello_controller.rb", "# DEPRECATEME: this action is no longer needed"
    app_file "db/some_seeds.rb", "# TODO: default tags such as TODO are still present"

    add_to_config 'config.annotations.register_tags "TESTME", "DEPRECATEME"'

    assert_equal <<~OUTPUT, run_notes_command
      app/controllers/hello_controller.rb:
        * [1] [DEPRECATEME] this action is no longer needed

      app/models/profile.rb:
        * [1] [TESTME] some method to test

      db/some_seeds.rb:
        * [1] [TODO] default tags such as TODO are still present

    OUTPUT
  end

  test "does not display results from tags that are neither default nor registered" do
    app_file "app/models/profile.rb", "# TESTME: some method to test"
    app_file "app/controllers/hello_controller.rb", "# DEPRECATEME: this action is no longer needed"
    app_file "db/some_seeds.rb", "# TODO: default tags such as TODO are still present"
    app_file "db/some_other_seeds.rb", "# BAD: this note should not be listed"

    add_to_config 'config.annotations.register_tags "TESTME", "DEPRECATEME"'

    assert_equal <<~OUTPUT, run_notes_command
      app/controllers/hello_controller.rb:
        * [1] [DEPRECATEME] this action is no longer needed

      app/models/profile.rb:
        * [1] [TESTME] some method to test

      db/some_seeds.rb:
        * [1] [TODO] default tags such as TODO are still present

    OUTPUT
  end

  test "does not pick up notes inside string literals" do
    app_file "app/models/profile.rb", '"# TODO: do something"'

    assert_empty run_notes_command
  end

  private
    def run_notes_command(args = [])
      rails "notes", args
    end
end
