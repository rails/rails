# frozen_string_literal: true

module ActiveRecord
  # = Active Record \Timestamp
  #
  # Active Record automatically timestamps create and update operations if the
  # table has fields named <tt>created_at/created_on</tt> or
  # <tt>updated_at/updated_on</tt>.
  #
  # Timestamping can be turned off by setting:
  #
  #   config.active_record.record_timestamps = false
  #
  # Timestamps are in UTC by default but you can use the local timezone by setting:
  #
  #   config.active_record.default_timezone = :local
  #
  # == Time Zone aware attributes
  #
  # Active Record keeps all the <tt>datetime</tt> and <tt>time</tt> columns
  # timezone aware. By default, these values are stored in the database as UTC
  # and converted back to the current <tt>Time.zone</tt> when pulled from the database.
  #
  # This feature can be turned off completely by setting:
  #
  #   config.active_record.time_zone_aware_attributes = false
  #
  # You can also specify that only <tt>datetime</tt> columns should be time-zone
  # aware (while <tt>time</tt> should not) by setting:
  #
  #   ActiveRecord::Base.time_zone_aware_types = [:datetime]
  #
  # You can also add database specific timezone aware types. For example, for PostgreSQL:
  #
  #   ActiveRecord::Base.time_zone_aware_types += [:tsrange, :tstzrange]
  #
  # Finally, you can indicate specific attributes of a model for which time zone
  # conversion should not applied, for instance by setting:
  #
  #   class Topic < ActiveRecord::Base
  #     self.skip_time_zone_conversion_for_attributes = [:written_on]
  #   end
  module Timestamp
    extend ActiveSupport::Concern

    included do
      class_attribute :record_timestamps, default: true
    end

    def initialize_dup(other) # :nodoc:
      super
      clear_timestamp_attributes
    end

    class_methods do
      private
        def timestamp_attributes_for_create_in_model
          timestamp_attributes_for_create.select { |c| column_names.include?(c) }
        end

        def timestamp_attributes_for_update_in_model
          timestamp_attributes_for_update.select { |c| column_names.include?(c) }
        end

        def all_timestamp_attributes_in_model
          timestamp_attributes_for_create_in_model + timestamp_attributes_for_update_in_model
        end

        def timestamp_attributes_for_create
          ["created_at", "created_on"]
        end

        def timestamp_attributes_for_update
          ["updated_at", "updated_on"]
        end

        def current_time_from_proper_timezone
          default_timezone == :utc ? Time.now.utc : Time.now
        end
    end

  private

    def _create_record
      if record_timestamps
        current_time = current_time_from_proper_timezone

        all_timestamp_attributes_in_model.each do |column|
          if !attribute_present?(column)
            _write_attribute(column, current_time)
          end
        end
      end

      super
    end

    def _update_record(*args, touch: true, **options)
      if touch && should_record_timestamps?
        current_time = current_time_from_proper_timezone

        timestamp_attributes_for_update_in_model.each do |column|
          next if will_save_change_to_attribute?(column)
          _write_attribute(column, current_time)
        end
      end
      super(*args)
    end

    def should_record_timestamps?
      record_timestamps && (!partial_writes? || has_changes_to_save?)
    end

    def timestamp_attributes_for_create_in_model
      self.class.send(:timestamp_attributes_for_create_in_model)
    end

    def timestamp_attributes_for_update_in_model
      self.class.send(:timestamp_attributes_for_update_in_model)
    end

    def all_timestamp_attributes_in_model
      self.class.send(:all_timestamp_attributes_in_model)
    end

    def current_time_from_proper_timezone
      self.class.send(:current_time_from_proper_timezone)
    end

    def max_updated_column_timestamp(timestamp_names = timestamp_attributes_for_update_in_model)
      timestamp_names
        .map { |attr| self[attr] }
        .compact
        .map(&:to_time)
        .max
    end

    # Clear attributes and changed_attributes
    def clear_timestamp_attributes
      all_timestamp_attributes_in_model.each do |attribute_name|
        self[attribute_name] = nil
        clear_attribute_changes([attribute_name])
      end
    end
  end
end
