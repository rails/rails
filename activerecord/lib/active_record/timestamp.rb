module ActiveRecord
  # Active Records will automatically record creation and/or update timestamps of database objects
  # if fields of the names created_at/created_on or updated_at/updated_on are present. This module is
  # automatically included, so you don't need to do that manually.
  #
  # This behavior can be turned off by setting <tt>ActiveRecord::Base.record_timestamps = false</tt>.
  module Timestamp 
    def self.append_features(base) # :nodoc:
      super
      base.before_create :timestamp_before_create
      base.before_update :timestamp_before_update
    end    
      
    def timestamp_before_create
      write_attribute("created_at", Time.now) if record_timestamps && respond_to?(:created_at) && created_at.nil?
      write_attribute("created_on", Time.now) if record_timestamps && respond_to?(:created_on) && created_on.nil?
      timestamp_before_update
    end

    def timestamp_before_update
      write_attribute("updated_at", Time.now) if record_timestamps && respond_to?(:updated_at)
      write_attribute("updated_on", Time.now) if record_timestamps && respond_to?(:updated_on)
    end
  end 

  class Base
    # Records the creation date and possibly time in created_on (date only) or created_at (date and time) and the update date and possibly
    # time in updated_on and updated_at. This only happens if the object responds to either of these messages, which they will do automatically
    # if the table has columns of either of these names. This feature is turned on by default.
    @@record_timestamps = true
    cattr_accessor :record_timestamps
  end
end