module ActiveRecord
  module Integration
    extend ActiveSupport::Concern

    included do
      ##
      # :singleton-method:
      # Indicates the format used to generate the timestamp in the cache key.
      # Accepts any of the symbols in <tt>Time::DATE_FORMATS</tt>.
      #
      # This is +:nsec+, by default.
      class_attribute :cache_timestamp_format, :instance_writer => false
      self.cache_timestamp_format = :nsec
    end

    # Returns a String, which Action Pack uses for constructing an URL to this
    # object. The default implementation returns this record's id as a String,
    # or nil if this record's unsaved.
    #
    # For example, suppose that you have a User model, and that you have a
    # <tt>resources :users</tt> route. Normally, +user_path+ will
    # construct a path with the user object's 'id' in it:
    #
    #   user = User.find_by(name: 'Phusion')
    #   user_path(user)  # => "/users/1"
    #
    # You can override +to_param+ in your model to make +user_path+ construct
    # a path using the user's name instead of the user's id:
    #
    #   class User < ActiveRecord::Base
    #     def to_param  # overridden
    #       name
    #     end
    #   end
    #
    #   user = User.find_by(name: 'Phusion')
    #   user_path(user)  # => "/users/Phusion"
    def to_param
      # We can't use alias_method here, because method 'id' optimizes itself on the fly.
      id && id.to_s # Be sure to stringify the id for routes
    end

    # Returns a cache key that can be used to identify this record.
    #
    #   Product.new.cache_key     # => "products/new"
    #   Product.find(5).cache_key # => "products/5" (updated_at not available)
    #   Person.find(5).cache_key  # => "people/5-20071224150000" (updated_at available)
    def cache_key
      case
      when new_record?
        "#{self.class.model_name.cache_key}/new"
      when timestamp = max_updated_column_timestamp
        timestamp = timestamp.utc.to_s(cache_timestamp_format)
        "#{self.class.model_name.cache_key}/#{id}-#{timestamp}"
      else
        "#{self.class.model_name.cache_key}/#{id}"
      end
    end
  end
end
