require "cases/migration/helper"

module ActiveRecord
  class Migration
    class RenameColumnTest < ActiveRecord::TestCase
      include ActiveRecord::Migration::TestHelper

      self.use_transactional_fixtures = false

      # FIXME: this is more of an integration test with AR::Base and the
      # schema modifications.  Maybe we should move this?
      def test_add_rename
        add_column "test_models", "girlfriend", :string
        TestModel.reset_column_information

        TestModel.create :girlfriend => 'bobette'

        rename_column "test_models", "girlfriend", "exgirlfriend"

        TestModel.reset_column_information
        bob = TestModel.find(:first)

        assert_equal "bobette", bob.exgirlfriend
      end

      # FIXME: another integration test.  We should decouple this from the
      # AR::Base implementation.
      def test_rename_column_using_symbol_arguments
        add_column :test_models, :first_name, :string

        TestModel.create :first_name => 'foo'

        rename_column :test_models, :first_name, :nick_name
        TestModel.reset_column_information
        assert TestModel.column_names.include?("nick_name")
        assert_equal ['foo'], TestModel.find(:all).map(&:nick_name)
      end

      # FIXME: another integration test.  We should decouple this from the
      # AR::Base implementation.
      def test_rename_column
        add_column "test_models", "first_name", "string"

        TestModel.create :first_name => 'foo'

        rename_column "test_models", "first_name", "nick_name"
        TestModel.reset_column_information
        assert TestModel.column_names.include?("nick_name")
        assert_equal ['foo'], TestModel.find(:all).map(&:nick_name)
      end
    end
  end
end
