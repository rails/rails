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
  module Timestamp
    extend ActiveSupport::Concern

    included do
      class_inheritable_accessor :record_timestamps, :instance_writer => false
      self.record_timestamps = true
    end
    
    # Saves the record with the updated_at/on attributes set to the current time.
    # Please note that no validation is performed and no callbacks are executed.
    # If an attribute name is passed, that attribute is updated along with 
    # updated_at/on attributes.
    #
    # Examples:
    #
    #   product.touch               # updates updated_at/on
    #   product.touch(:designed_at) # updates the designed_at attribute and updated_at/on
    def touch(attribute = nil)
      update_attribute(attribute, current_time_from_proper_timezone)
    end

  private

    def create #:nodoc:
      if record_timestamps
        current_time = current_time_from_proper_timezone

        timestamp_attributes_for_create.each do |column|
          write_attribute(column.to_s, current_time) if respond_to?(column) && self.send(column).nil?
        end

        timestamp_attributes_for_update_in_model.each do |column|
          write_attribute(column.to_s, current_time) if self.send(column).nil?
        end
      end

      super
    end

    def update(*args) #:nodoc:
      record_update_timestamps if !partial_updates? || changed?
      super
    end

    def record_update_timestamps #:nodoc:
      return unless record_timestamps
      current_time = current_time_from_proper_timezone
      timestamp_attributes_for_update_in_model.inject({}) do |hash, column|
        hash[column.to_s] = write_attribute(column.to_s, current_time)
        hash
      end
    end

    def timestamp_attributes_for_update_in_model #:nodoc:
      timestamp_attributes_for_update.select { |elem| respond_to?(elem) }
    end

    def timestamp_attributes_for_update #:nodoc:
      [:updated_at, :updated_on]
    end

    def timestamp_attributes_for_create #:nodoc:
      [:created_at, :created_on]
    end

    def all_timestamp_attributes #:nodoc:
      timestamp_attributes_for_update + timestamp_attributes_for_create
    end
    
    def current_time_from_proper_timezone #:nodoc:
      self.class.default_timezone == :utc ? Time.now.utc : Time.now
    end
  end
end

