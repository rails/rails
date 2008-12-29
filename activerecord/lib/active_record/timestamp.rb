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
    def self.included(base) #:nodoc:
      base.alias_method_chain :create, :timestamps
      base.alias_method_chain :update, :timestamps

      base.class_inheritable_accessor :record_timestamps, :instance_writer => false
      base.record_timestamps = true
    end

    private
      def create_with_timestamps #:nodoc:
        if record_timestamps
          t = self.class.default_timezone == :utc ? Time.now.utc : Time.now
          write_attribute('created_at', t) if respond_to?(:created_at) && created_at.nil?
          write_attribute('created_on', t) if respond_to?(:created_on) && created_on.nil?

          write_attribute('updated_at', t) if respond_to?(:updated_at) && updated_at.nil?
          write_attribute('updated_on', t) if respond_to?(:updated_on) && updated_on.nil?
        end
        create_without_timestamps
      end

      def update_with_timestamps(*args) #:nodoc:
        if record_timestamps && (!partial_updates? || changed?)
          t = self.class.default_timezone == :utc ? Time.now.utc : Time.now
          write_attribute('updated_at', t) if respond_to?(:updated_at)
          write_attribute('updated_on', t) if respond_to?(:updated_on)
        end
        update_without_timestamps(*args)
      end
  end
end
