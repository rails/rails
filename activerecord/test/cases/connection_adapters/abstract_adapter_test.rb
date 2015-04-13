# encoding: utf-8
require "cases/helper"
require 'support/ddl_helper'
require 'support/connection_helper'

module ActiveRecord
  module ConnectionAdapters
    class AbstractAdapterTest < ActiveRecord::TestCase
      include ConnectionHelper

      class Reminder < ActiveRecord::Base; end
      teardown do
        ActiveRecord::Base.table_name_prefix = ""
        ActiveRecord::Base.table_name_suffix = ""
      end

      def test_proper_table_name_on_abstract_adapter
        reminder_class = new_isolated_reminder_class
        abstract_adapter = ActiveRecord::ConnectionAdapters::AbstractAdapter.new({})
        assert_equal "table", abstract_adapter.proper_table_name('table')
        assert_equal "table", abstract_adapter.proper_table_name(:table)
        assert_equal "reminders", abstract_adapter.proper_table_name(reminder_class)
        reminder_class.reset_table_name
        assert_equal reminder_class.table_name, abstract_adapter.proper_table_name(reminder_class)
    
        # Use the model's own prefix/suffix if a model is given
        ActiveRecord::Base.table_name_prefix = "ARprefix_"
        ActiveRecord::Base.table_name_suffix = "_ARsuffix"
        reminder_class.table_name_prefix = 'prefix_'
        reminder_class.table_name_suffix = '_suffix'
        reminder_class.reset_table_name
        assert_equal "prefix_reminders_suffix", abstract_adapter.proper_table_name(reminder_class)
        reminder_class.table_name_prefix = ''
        reminder_class.table_name_suffix = ''
        reminder_class.reset_table_name
    
        # Use AR::Base's prefix/suffix if string or symbol is given
        ActiveRecord::Base.table_name_prefix = "prefix_"
        ActiveRecord::Base.table_name_suffix = "_suffix"
        reminder_class.reset_table_name
        assert_equal "prefix_table_suffix", abstract_adapter.proper_table_name('table', abstract_adapter.table_name_options)
        assert_equal "prefix_table_suffix", abstract_adapter.proper_table_name(:table, abstract_adapter.table_name_options)
      end

    protected
      # This is needed to isolate class_attribute assignments like `table_name_prefix`
      # for each test case.
      def new_isolated_reminder_class
        Class.new(Reminder) {
          def self.name; "Reminder"; end
          def self.base_class; self; end
        }
      end
    end
  end
end
