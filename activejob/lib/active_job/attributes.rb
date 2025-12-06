# frozen_string_literal: true

module ActiveJob
  # = Active Job \Attributes
  #
  # Allows defining custom job attributes that will be serialized and deserialized along with
  # the job arguments. Useful for cross-cutting concerns.
  #
  #   module ShardedJob
  #     extend ActiveSupport::Concern
  #
  #     included do
  #       attribute :shard
  #       attribute :class_name
  #
  #       around_perform do |job, block|
  #         klass = job.class_name&.constantize || ActiveRecord::Base
  #         klass.connected_to(shard: job.shard.to_sym, &block)
  #       end
  #     end
  #   end
  #
  #   class UserDeletionJob < ActiveJob::Base
  #     include ShardedJob
  #
  #     # ...
  #   end
  #
  # Once an attribute has been configured, it can be set on job instances with normal assignment
  # _or_ it can be set via the +set+ method:
  #
  #   job = UserDeletionJob.new(user_id)
  #   job.set(shard: shard_id)
  #   job.enqueue
  #
  # This includes the various ways that +set+ can be called, e.g.
  #
  #   UserDeletionJob.set(shard: shard_id).new(user_id).enqueue
  #   UserDeletionJob.new(user_id).enqueue(shard: shard_id)
  #
  module Attributes
    extend ActiveSupport::Concern

    class_methods do
      def attribute(name)
        if respond_to?(name)
          raise ArgumentError, "Attribute #{name} is already defined"
        end

        attributes.include?(name.to_s)
        attr_accessor name
      end

      # The attributes defined on the class, as well as their options.
      #
      # Will be inherited to subclasses.
      def attributes
        @attributes ||=
          if superclass.respond_to?(:attributes)
            superclass.attributes.dup
          else
            Set.new
          end
      end
    end

    def set(options = {})
      options.each_key do |name|
        if self.class.attributes.include?(name.to_s)
          send("#{name}=", options.delete(name))
        end
      end

      super
    end

    def serialize
      data = super

      self.class.attributes.each do |name|
        data[name] = Arguments.serialize_argument(send(name))
      end

      data
    end

    def deserialize(job_data)
      self.class.attributes.each do |attr|
        send("#{attr}=", Arguments.deserialize_argument(job_data[attr]))
      end

      super
    end
  end
end
