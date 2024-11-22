# frozen_string_literal: true

require "active_support/callbacks"
require "active_support/core_ext/object/with"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/module/delegation"

module ActiveSupport
  # = Current Attributes
  #
  # Abstract super class that provides a thread-isolated attributes singleton, which resets automatically
  # before and after each request. This allows you to keep all the per-request attributes easily
  # available to the whole system.
  #
  # The following full app-like example demonstrates how to use a Current class to
  # facilitate easy access to the global, per-request attributes without passing them deeply
  # around everywhere:
  #
  #   # app/models/current.rb
  #   class Current < ActiveSupport::CurrentAttributes
  #     attribute :account, :user
  #     attribute :request_id, :user_agent, :ip_address
  #
  #     resets { Time.zone = nil }
  #
  #     def user=(user)
  #       super
  #       self.account = user.account
  #       Time.zone    = user.time_zone
  #     end
  #   end
  #
  #   # app/controllers/concerns/authentication.rb
  #   module Authentication
  #     extend ActiveSupport::Concern
  #
  #     included do
  #       before_action :authenticate
  #     end
  #
  #     private
  #       def authenticate
  #         if authenticated_user = User.find_by(id: cookies.encrypted[:user_id])
  #           Current.user = authenticated_user
  #         else
  #           redirect_to new_session_url
  #         end
  #       end
  #   end
  #
  #   # app/controllers/concerns/set_current_request_details.rb
  #   module SetCurrentRequestDetails
  #     extend ActiveSupport::Concern
  #
  #     included do
  #       before_action do
  #         Current.request_id = request.uuid
  #         Current.user_agent = request.user_agent
  #         Current.ip_address = request.ip
  #       end
  #     end
  #   end
  #
  #   class ApplicationController < ActionController::Base
  #     include Authentication
  #     include SetCurrentRequestDetails
  #   end
  #
  #   class MessagesController < ApplicationController
  #     def create
  #       Current.account.messages.create(message_params)
  #     end
  #   end
  #
  #   class Message < ApplicationRecord
  #     belongs_to :creator, default: -> { Current.user }
  #     after_create { |message| Event.create(record: message) }
  #   end
  #
  #   class Event < ApplicationRecord
  #     before_create do
  #       self.request_id = Current.request_id
  #       self.user_agent = Current.user_agent
  #       self.ip_address = Current.ip_address
  #     end
  #   end
  #
  # A word of caution: It's easy to overdo a global singleton like Current and tangle your model as a result.
  # Current should only be used for a few, top-level globals, like account, user, and request details.
  # The attributes stuck in Current should be used by more or less all actions on all requests. If you start
  # sticking controller-specific attributes in there, you're going to create a mess.
  class CurrentAttributes
    include ActiveSupport::Callbacks
    define_callbacks :reset

    INVALID_ATTRIBUTE_NAMES = [:set, :reset, :resets, :instance, :before_reset, :after_reset, :reset_all, :clear_all] # :nodoc:

    NOT_SET = Object.new.freeze # :nodoc:

    class << self
      # Returns singleton instance for this class in this thread. If none exists, one is created.
      def instance
        current_instances[current_instances_key] ||= new
      end

      # Declares one or more attributes that will be given both class and instance accessor methods.
      #
      # ==== Options
      #
      # * <tt>:default</tt> - The default value for the attributes. If the value
      # is a proc or lambda, it will be called whenever an instance is
      # constructed. Otherwise, the value will be duplicated with +#dup+.
      # Default values are re-assigned when the attributes are reset.
      def attribute(*names, default: NOT_SET)
        invalid_attribute_names = names.map(&:to_sym) & INVALID_ATTRIBUTE_NAMES
        if invalid_attribute_names.any?
          raise ArgumentError, "Restricted attribute names: #{invalid_attribute_names.join(", ")}"
        end

        ActiveSupport::CodeGenerator.batch(generated_attribute_methods, __FILE__, __LINE__) do |owner|
          names.each do |name|
            owner.define_cached_method(name, namespace: :current_attributes) do |batch|
              batch <<
                "def #{name}" <<
                "@attributes[:#{name}]" <<
                "end"
            end
            owner.define_cached_method("#{name}=", namespace: :current_attributes) do |batch|
              batch <<
                "def #{name}=(value)" <<
                "@attributes[:#{name}] = value" <<
                "end"
            end
          end
        end

        Delegation.generate(singleton_class, names, to: :instance, nilable: false, signature: "")
        Delegation.generate(singleton_class, names.map { |n| "#{n}=" }, to: :instance, nilable: false, signature: "value")

        self.defaults = defaults.merge(names.index_with { default })
      end

      # Calls this callback before #reset is called on the instance. Used for resetting external collaborators that depend on current values.
      def before_reset(*methods, &block)
        set_callback :reset, :before, *methods, &block
      end

      # Calls this callback after #reset is called on the instance. Used for resetting external collaborators, like Time.zone.
      def resets(*methods, &block)
        set_callback :reset, :after, *methods, &block
      end
      alias_method :after_reset, :resets

      delegate :set, :reset, to: :instance

      def reset_all # :nodoc:
        current_instances.each_value(&:reset)
      end

      def clear_all # :nodoc:
        reset_all
        current_instances.clear
      end

      private
        def generated_attribute_methods
          @generated_attribute_methods ||= Module.new.tap { |mod| include mod }
        end

        def current_instances
          IsolatedExecutionState[:current_attributes_instances] ||= {}
        end

        def current_instances_key
          @current_instances_key ||= name.to_sym
        end

        def method_missing(name, ...)
          instance.public_send(name, ...)
        end

        def respond_to_missing?(name, _)
          instance.respond_to?(name) || super
        end

        def method_added(name)
          super
          return if name == :initialize
          return unless public_method_defined?(name)
          return if respond_to?(name, true)
          Delegation.generate(singleton_class, [name], to: :instance, as: self, nilable: false)
        end
    end

    class_attribute :defaults, instance_writer: false, default: {}.freeze

    attr_writer :attributes

    def initialize
      @attributes = resolve_defaults
    end

    def attributes
      @attributes.dup
    end

    # Expose one or more attributes within a block. Old values are returned after the block concludes.
    # Example demonstrating the common use of needing to set Current attributes outside the request-cycle:
    #
    #   class Chat::PublicationJob < ApplicationJob
    #     def perform(attributes, room_number, creator)
    #       Current.set(person: creator) do
    #         Chat::Publisher.publish(attributes: attributes, room_number: room_number)
    #       end
    #     end
    #   end
    def set(attributes, &block)
      with(**attributes, &block)
    end

    # Reset all attributes. Should be called before and after actions, when used as a per-request singleton.
    def reset
      run_callbacks :reset do
        self.attributes = resolve_defaults
      end
    end

    private
      def resolve_defaults
        defaults.each_with_object({}) do |(key, value), result|
          if value != NOT_SET
            result[key] = Proc === value ? value.call : value.dup
          end
        end
      end
  end
end
