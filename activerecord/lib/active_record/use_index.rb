# frozen_string_literal: true

module ActiveRecord
  # Allow passing index hints to MySQL in case the query planner gets confused.
  #
  # MySQL documentation:
  #    https://dev.mysql.com/doc/refman/5.7/en/index-hints.html
  #
  # Example:
  #   Message.first.events.use_index(:index_events_on_eventable_type_and_eventable_id)
  #
  #   => Event Load (0.5ms)  SELECT `events`.* FROM `events` USE INDEX (index_events_on_eventable_type_and_eventable_id)
  #      WHERE `events`.`eventable_id` = 123 AND `events`.`eventable_type` = 'Message'
  #
  module UseIndex
    extend ActiveSupport::Concern

    module ClassMethods
      def use_index(name)
        return from(quoted_table_name) unless connection.supports_use_index?
        from "#{quoted_table_name} USE INDEX (#{name})"
      end
    end
  end
end
