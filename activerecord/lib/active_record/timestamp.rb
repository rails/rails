
module ActiveRecord
  ActiveSupport.on_load(:active_record_config) do
    mattr_accessor :record_timestamps, instance_accessor: false
    self.record_timestamps = true
  end

  # = Active Record Timestamp
  #
  # Active Record automatically timestamps create and update operations if the
  # table has fields named <tt>created_at/created_on</tt> or
  # <tt>updated_at/updated_on</tt>.
  #
  # Timestamping can be turned off by setting:
  #
  #   config.active_record.record_timestamps = false
  #
  # Timestamps are in the local timezone by default but you can use UTC by setting:
  #
  #   config.active_record.default_timezone = :utc
  #
  # == Time Zone aware attributes
  #
  # By default, ActiveRecord::Base keeps all the datetime columns time zone aware by executing following code.
  #
  #   config.active_record.time_zone_aware_attributes = true
  #
  # This feature can easily be turned off by assigning value <tt>false</tt> .
  #
  # If your attributes are time zone aware and you desire to skip time zone conversion to the current Time.zone
  # when reading certain attributes then you can do following:
  #
  #   class Topic < ActiveRecord::Base
  #     self.skip_time_zone_conversion_for_attributes = [:written_on]
  #   end
  module Timestamp
    extend ActiveSupport::Concern

    included do
      config_attribute :record_timestamps, instance_writer: true
    end

    def initialize_dup(other) # :nodoc:
      clear_timestamp_attributes
    end

  private

    def create
      if self.record_timestamps
        current_time = current_time_from_proper_timezone

        all_timestamp_attributes.each do |column|
          if respond_to?(column) && respond_to?("#{column}=") && self.send(column).nil?
            write_attribute(column.to_s, current_time)
          end
        end
      end

      super
    end

    def update(*args)
      if should_record_timestamps?
        current_time = current_time_from_proper_timezone

        timestamp_attributes_for_update_in_model.each do |column|
          column = column.to_s
          next if attribute_changed?(column)
          write_attribute(column, current_time)
        end
      end
      super
    end

    def should_record_timestamps?
      self.record_timestamps && (!partial_updates? || changed? || (attributes.keys & self.class.serialized_attributes.keys).present?)
    end

    def timestamp_attributes_for_create_in_model
      timestamp_attributes_for_create.select { |c| self.class.column_names.include?(c.to_s) }
    end

    def timestamp_attributes_for_update_in_model
      timestamp_attributes_for_update.select { |c| self.class.column_names.include?(c.to_s) }
    end

    def all_timestamp_attributes_in_model
      timestamp_attributes_for_create_in_model + timestamp_attributes_for_update_in_model
    end

    def timestamp_attributes_for_update
      [:updated_at, :updated_on]
    end

    def timestamp_attributes_for_create
      [:created_at, :created_on]
    end

    def all_timestamp_attributes
      timestamp_attributes_for_create + timestamp_attributes_for_update
    end

    def current_time_from_proper_timezone
      self.class.default_timezone == :utc ? Time.now.utc : Time.now
    end

    # Clear attributes and changed_attributes
    def clear_timestamp_attributes
      all_timestamp_attributes_in_model.each do |attribute_name|
        self[attribute_name] = nil
        changed_attributes.delete(attribute_name)
      end
    end
  end
end
