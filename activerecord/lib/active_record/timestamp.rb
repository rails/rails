module ActiveRecord
  # Active Records will automatically record creation and/or update timestamps of database objects
  # if fields of the names created_at/created_on or updated_at/updated_on are present. This module is
  # automatically included, so you don't need to do that manually.
  #
  # This behavior can be turned off by setting <tt>ActiveRecord::Base.record_timestamps = false</tt>.
  # This behavior can use GMT by setting <tt>ActiveRecord::Base.timestamps_gmt = true</tt>
  module Timestamp 
    def self.append_features(base) # :nodoc:
      super

      base.class_eval do
        alias_method :create_without_timestamps, :create
        alias_method :create, :create_with_timestamps

        alias_method :update_without_timestamps, :update
        alias_method :update, :update_with_timestamps
      end
    end    
      
    def create_with_timestamps
      t = timestamps_gmt ? Time.now.gmtime : Time.now
      write_attribute("created_at", t) if record_timestamps && respond_to?(:created_at) && created_at.nil?
      write_attribute("created_on", t) if record_timestamps && respond_to?(:created_on) && created_on.nil?

      write_attribute("updated_at", t) if record_timestamps && respond_to?(:updated_at)
      write_attribute("updated_on", t) if record_timestamps && respond_to?(:updated_on)
      
      create_without_timestamps
    end

    def update_with_timestamps
      t = timestamps_gmt ? Time.now.gmtime : Time.now
      write_attribute("updated_at", t) if record_timestamps && respond_to?(:updated_at)
      write_attribute("updated_on", t) if record_timestamps && respond_to?(:updated_on)

      update_without_timestamps
    end
  end 

  class Base
    # Records the creation date and possibly time in created_on (date only) or created_at (date and time) and the update date and possibly
    # time in updated_on and updated_at. This only happens if the object responds to either of these messages, which they will do automatically
    # if the table has columns of either of these names. This feature is turned on by default.
    @@record_timestamps = true
    cattr_accessor :record_timestamps
    @@timestamps_gmt = false
    cattr_accessor :timestamps_gmt
  end
end
