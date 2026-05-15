# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class RakeDbsPostgreSQLTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation

      def setup
        build_app
      end

      def teardown
        teardown_app
      end

      test "db:create works when schema cache exists and database does not exist" do
        use_postgresql

        begin
          rails %w(db:create db:migrate db:schema:cache:dump)

          rails "db:drop"
          rails "db:create"
          assert_equal 0, $?.exitstatus
        ensure
          rails "db:drop" rescue nil
        end
      end

      test "db:schema:cache:dump dumps virtual columns" do
        Dir.chdir(app_path) do
          use_postgresql
          rails "db:drop", "db:create"

          rails "runner", <<~RUBY
            ActiveRecord::Base.lease_connection.create_table(:books) do |t|
              t.integer :pages
              t.virtual :pages_plus_1, type: :integer, as: "pages + 1", stored: true
            end
          RUBY

          rails "db:schema:cache:dump"

          virtual_column_exists = rails("runner", "p ActiveRecord::Base.schema_cache.columns('books')[2].virtual?").strip
          assert_equal "true", virtual_column_exists
        end
      end

      test "db:prepare creates test database if it does not exist" do
        Dir.chdir(app_path) do
          db_name = use_postgresql
          rails "db:drop", "db:create"
          rails "runner", "ActiveRecord::Base.lease_connection.drop_database(:#{db_name}_test)"

          output = rails("db:prepare")
          assert_match(%r{Created database '#{db_name}_test'}, output)
        end
      ensure
        rails "db:drop" rescue nil
      end
    end
  end
end
