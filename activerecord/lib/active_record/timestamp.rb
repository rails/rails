module ActiveRecord
  # Active Records will automatically record creation and/or update timestamps of database objects
  # if fields of the names created_at/created_on or updated_at/updated_on are present.
  module Timestamp 
    def self.append_features(base) # :nodoc:
      super
      base.before_create :timestamp_before_create
      base.before_update :timestamp_before_update
    end    
      
    def timestamp_before_create
      write_attribute("created_at", Time.now) if respond_to?(:created_at) && created_at.nil?
      write_attribute("created_on", Time.now) if respond_to?(:created_on) && created_on.nil?
      timestamp_before_update
    end

    def timestamp_before_update
      write_attribute("updated_at", Time.now) if respond_to?(:updated_at)
      write_attribute("updated_on", Time.now) if respond_to?(:updated_on)
    end
  end 
end