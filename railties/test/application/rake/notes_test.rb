require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class RakeNotesTest < Test::Unit::TestCase
      def setup 
        build_app
        require "rails/all"
      end

      def teardown
        teardown_app
      end

      test 'notes' do

        app_file "app/views/home/index.html.erb", "<% # TODO: note in erb %>"
        app_file "app/views/home/index.html.haml", "-# TODO: note in haml"
        app_file "app/views/home/index.html.slim", "/ TODO: note in slim"
        app_file "app/assets/javascripts/application.js.coffee", "# TODO: note in coffee"
        app_file "app/controllers/application_controller.rb", 1000.times.map { "" }.join("\n") << "# TODO: note in ruby"

        boot_rails
        require 'rake'
        require 'rdoc/task'
        require 'rake/testtask'

        Rails.application.load_tasks

        Dir.chdir(app_path) do
          output = `bundle exec rake notes`

          assert_match /note in erb/, output
          assert_match /note in haml/, output
          assert_match /note in slim/, output
          assert_match /note in ruby/, output
          assert_match /note in coffee/, output
        end

      end

      private
      def boot_rails
        super
        require "#{app_path}/config/environment"
      end
    end
  end
end
