module ActiveRecord
  # Active Records will automatically record creation and/or update timestamps of database objects
  # if fields of the names created_at/created_on or updated_at/updated_on are present. This module is
  # automatically included, so you don't need to do that manually.
  #
  # This behavior can be turned off by setting <tt>ActiveRecord::Base.record_timestamps = false</tt>.
  # This behavior by default uses local time, but can use UTC by setting <tt>ActiveRecord::Base.default_timezone = :utc</tt>
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

    def create_with_timestamps #:nodoc:
      if record_timestamps
      t = ( self.class.default_timezone == :utc ? Time.now.utc : Time.now )
        write_attribute('created_at', t) if respond_to?(:created_at) && created_at.nil?
        write_attribute('created_on', t) if respond_to?(:created_on) && created_on.nil?

        write_attribute('updated_at', t) if respond_to?(:updated_at)
        write_attribute('updated_on', t) if respond_to?(:updated_on)
      end
      create_without_timestamps
    end

    def update_with_timestamps #:nodoc:
      if record_timestamps
      t = ( self.class.default_timezone == :utc ? Time.now.utc : Time.now )
        write_attribute('updated_at', t) if respond_to?(:updated_at)
        write_attribute('updated_on', t) if respond_to?(:updated_on)
      end
      update_without_timestamps
    end
  end

  class Base
    # Records the creation date and possibly time in created_on (date only) or created_at (date and time) and the update date and possibly
    # time in updated_on and updated_at. This only happens if the object responds to either of these messages, which they will do automatically
    # if the table has columns of either of these names. This feature is turned on by default.
    @@record_timestamps = true
    cattr_accessor :record_timestamps

    # deprecated: use ActiveRecord::Base.default_timezone instead.
    @@timestamps_gmt = false
    def self.timestamps_gmt=( gmt ) #:nodoc:
      warn "timestamps_gmt= is deprecated. use default_timezone= instead"
      self.default_timezone = ( gmt ? :utc : :local )
    end

    def self.timestamps_gmt #:nodoc:
      warn "timestamps_gmt is deprecated. use default_timezone instead"
      self.default_timezone == :utc
    end
  end
end
