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
    # If the save fails because of validation errors, an 
    # ActiveRecord::RecordInvalid exception is raised. If an attribute name is passed,
    # that attribute is used for the touch instead of the updated_at/on attributes.
    #
    # Examples:
    #
    #   product.touch               # updates updated_at
    #   product.touch(:designed_at) # updates the designed_at attribute
    def touch(attribute = nil)
      current_time = current_time_from_proper_timezone

      if attribute
        write_attribute(attribute, current_time)
      else
        timestamp_attributes_for_update_in_model.each { |column| write_attribute(column.to_s, current_time) }
      end

      save!
    end

  private
    def create #:nodoc:
      if record_timestamps
        current_time = current_time_from_proper_timezone

        write_attribute('created_at', current_time) if respond_to?(:created_at) && created_at.nil?
        write_attribute('created_on', current_time) if respond_to?(:created_on) && created_on.nil?

        timestamp_attributes_for_update.each do |column|
          write_attribute(column.to_s, current_time) if respond_to?(column) && self.send(column).nil?
        end
      end

      super
    end

    def update(*args) #:nodoc:
      record_update_timestamps
      super
    end

    def record_update_timestamps
      if should_record_update_timestamps
        current_time = current_time_from_proper_timezone
        timestamp_attributes_for_update_in_model.each { |column| write_attribute(column.to_s, current_time) }
      end
    end

    def should_record_update_timestamps
      record_timestamps && (!partial_updates? || changed?)
    end


    def timestamp_attributes_for_update #:nodoc:
      [:updated_at, :updated_on]
    end

    def timestamp_attributes_for_update_in_model #:nodoc:
      ([:updated_at, :updated_on].inject([]) { |sum, elem| respond_to?(elem) ? sum << elem : sum })
    end
    
    def current_time_from_proper_timezone #:nodoc:
      self.class.default_timezone == :utc ? Time.now.utc : Time.now
    end
  end
end

