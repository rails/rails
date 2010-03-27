module ActiveRecord
  # Active Record automatically timestamps create and update operations if the table has fields
  # named created_at/created_on or updated_at/updated_on.
  #
  # Timestamping can be turned off by setting
  #   <tt>ActiveRecord::Base.record_timestamps = false</tt>
  #
  # Timestamps are in the local timezone by default but you can use UTC by setting
  #   <tt>ActiveRecord::Base.default_timezone = :utc</tt>
  module Timestamp
    extend ActiveSupport::Concern

    included do
      alias_method_chain :create, :timestamps
      alias_method_chain :update, :timestamps

      class_inheritable_accessor :record_timestamps, :instance_writer => false
      self.record_timestamps = true
    end
    
    # Saves the record with the updated_at/on attributes set to the current time.
    # If the save fails because of validation errors, an ActiveRecord::RecordInvalid exception is raised.
    # If an attribute name is passed, that attribute is used for the touch instead of the updated_at/on attributes.
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
        write_attribute('updated_at', current_time) if respond_to?(:updated_at)
        write_attribute('updated_on', current_time) if respond_to?(:updated_on)
      end

      save!
    end


    private
      def create_with_timestamps #:nodoc:
        if record_timestamps
          current_time = current_time_from_proper_timezone

          write_attribute('created_at', current_time) if respond_to?(:created_at) && created_at.nil?
          write_attribute('created_on', current_time) if respond_to?(:created_on) && created_on.nil?

          write_attribute('updated_at', current_time) if respond_to?(:updated_at) && updated_at.nil?
          write_attribute('updated_on', current_time) if respond_to?(:updated_on) && updated_on.nil?
        end

        create_without_timestamps
      end

      def update_with_timestamps(*args) #:nodoc:
        if record_timestamps && (!partial_updates? || changed?)
          current_time = current_time_from_proper_timezone

          write_attribute('updated_at', current_time) if respond_to?(:updated_at)
          write_attribute('updated_on', current_time) if respond_to?(:updated_on)
        end

        update_without_timestamps(*args)
      end
      
      def current_time_from_proper_timezone
        self.class.default_timezone == :utc ? Time.now.utc : Time.now
      end
  end
end