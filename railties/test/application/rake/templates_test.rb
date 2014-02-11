require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class TemplatesTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation

      def setup
        build_app
        require "rails/all"
        super
      end

      def teardown
        super
        teardown_app
      end

      def test_rake_template
        Dir.chdir(app_path) do
          cmd = "bundle exec rake rails:template LOCATION=foo"
          r,w = IO.pipe
          Process.waitpid Process.spawn(cmd, out: w, err: w)
          w.close
          assert_match(/Could not find.*foo/, r.read)
          r.close
        end
      end
    end
  end
end

