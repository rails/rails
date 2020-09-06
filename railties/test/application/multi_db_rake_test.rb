# frozen_string_literal: true

require 'isolation/abstract_unit'
require 'env_helpers'

module ApplicationTests
  class MultiDbRakeTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation, EnvHelpers

    def setup
      build_app(multi_db: true)
      @output = rails('generate', 'scaffold', 'Pet', 'name:string', '--database=animals')
    end

    def teardown
      teardown_app
    end

    def test_generate_scaffold_creates_abstract_model
      assert_match %r{app/models/pet\.rb}, @output
      assert_match %r{app/models/animals_record\.rb}, @output
    end

    def test_destroy_scaffold_doesnt_remove_abstract_model
      output = rails('destroy', 'scaffold', 'Pet', '--database=animals')

      assert_match %r{app/models/pet\.rb}, output
      assert_no_match %r{app/models/animals_record\.rb}, output
    end

    def test_creates_a_directory_for_migrations
      assert_match %r{db/animals_migrate/}, @output
    end
  end
end
