require 'abstract_unit'
require 'generator/generator_test_helper'

class AppTest < GeneratorTestCase

  def test_application_skeleton_is_created
    run_generator

    %w(
      app/controllers
      app/helpers
      app/models
      app/views/layouts
      config/environments
      config/initializers
      config/locales
      db
      doc
      lib
      lib/tasks
      log
      public/images
      public/javascripts
      public/stylesheets
      script/performance
      test/fixtures
      test/functional
      test/integration
      test/performance
      test/unit
      vendor
      vendor/plugins
      tmp/sessions
      tmp/sockets
      tmp/cache
      tmp/pids
    ).each{ |path| assert_file path }
  end

  def test_template_raises_an_error_with_invalid_path
    content = capture(:stderr){ run_generator(["-m", "non/existant/path"]) }
    assert_match /The template \[.*\] could not be loaded/, content
    assert_match /non\/existant\/path/, content
  end

  def test_template_is_executed_when_supplied
    path = "http://gist.github.com/103208.txt"
    template = %{ say "It works!" }
    template.instance_eval "def read; self; end" # Make the string respond to read

    generator(:template => path, :database => "sqlite3").expects(:open).with(path).returns(template)
    assert_match /It works!/, silence(:stdout){ generator.invoke(:all) }
  end

  protected

    def run_generator(args=[])
      silence(:stdout) { Rails::Generators::App.start [destination_root].concat(args) }
    end

    def generator(options={})
      @generator ||= Rails::Generators::App.new([destination_root], options, :root => destination_root)
    end

end
