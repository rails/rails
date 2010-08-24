module ActiveRecord
  # = Active Record Timestamp
  #
  # Active Record automatically timestamps create and update operations if the
  # table has fields named <tt>created_at/created_on</tt> or
  # <tt>updated_at/updated_on</tt>.
  #
  # Timestamping can be turned off by setting:
  #
  #   <tt>ActiveRecord::Base.record_timestamps = false</tt>
  #
  # Timestamps are in the local timezone by default but you can use UTC by setting:
  #
  #   <tt>ActiveRecord::Base.default_timezone = :utc</tt>
  #
  # == Time Zone aware attributes
  #
  # By default, ActiveRecord::Base keeps all the datetime columns time zone aware by executing following code.
  #
  #   ActiveRecord::Base.time_zone_aware_attributes = true
  #
  # This feature can easily be turned off by assigning value <tt>false</tt> .
  #
  # If your attributes are time zone aware and you desire to skip time zone conversion for certain
  # attributes then you can do following:
  #
  #   Topic.skip_time_zone_conversion_for_attributes = [:written_on]
  module Timestamp
    extend ActiveSupport::Concern

    included do
      class_inheritable_accessor :record_timestamps, :instance_writer => false
      self.record_timestamps = true
    end

  private

    def create #:nodoc:
      if record_timestamps
        current_time = current_time_from_proper_timezone

        all_timestamp_attributes.each do |column|
          write_attribute(column.to_s, current_time) if respond_to?(column) && self.send(column).nil?
        end
      end

      super
    end

    def update(*args) #:nodoc:
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
      record_timestamps && (!partial_updates? || changed?)
    end

    def timestamp_attributes_for_update_in_model
      timestamp_attributes_for_update.select { |c| respond_to?(c) }
    end

    def timestamp_attributes_for_update #:nodoc:
      [:updated_at, :updated_on]
    end

    def timestamp_attributes_for_create #:nodoc:
      [:created_at, :created_on]
    end

    def all_timestamp_attributes #:nodoc:
      timestamp_attributes_for_create + timestamp_attributes_for_update
    end

    def current_time_from_proper_timezone #:nodoc:
      self.class.default_timezone == :utc ? Time.now.utc : Time.now
    end
  end
end

