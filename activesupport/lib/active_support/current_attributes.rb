module ActiveSupport
  # Abstract super class that provides a thread-isolated attributes singleton.
  # Primary use case is keeping all the per-request attributes easily available to the whole system.
  #
  # The following full app-like example demonstrates how to use a Current class to
  # facilitate easy access to the global, per-request attributes without passing them deeply
  # around everywhere:
  #
  #   # app/services/current.rb
  #   require 'active_support/current_attributes'
  #
  #   class Current < ActiveSupport::CurrentAttributes
  #     attribute :account, :user
  #     attribute :request_id, :user_agent, :ip_address
  #
  #     resets { Time.zone = nil }
  #
  #     def user=(user)
  #       attributes[:user] = user
  #       self.account = user.try(:account)
  #       Time.zone = user.try(:time_zone)
  #     end
  #   end
  #
  #   module Current::Reset
  #     extend ActiveSupport::Concern
  #
  #     included do
  #       before_action { Current.reset }
  #       after_action  { Current.reset }
  #     end
  #   end
  #
  #   # app/controllers/concerns/authentication.rb
  #   module Authentication
  #     extend ActiveSupport::Concern
  #
  #     included do
  #       before_action :set_current_authenticated_user
  #     end
  #
  #     private
  #       def set_current_authenticated_user
  #         Current.user = User.find(cookies.signed[:user_id])
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
  #     include Current::Reset
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

    class << self
      # Returns singleton instance for this class in this thread. If none exists, one is created.
      def instance
        Thread.current[:"current_attributes_for_#{name}"] ||= new
      end

      # Declares one or more attributes that will be given both class and instance accessor methods.
      def attribute(*names)
        generated_attribute_methods.module_eval do
          names.each do |name|
            define_method(name) do
              attributes[name.to_sym]
            end

            define_method("#{name}=") do |attribute|
              attributes[name.to_sym] = attribute
            end
          end
        end

        names.each do |name|
          define_singleton_method(name) do
            instance.public_send(name)
          end

          define_singleton_method("#{name}=") do |attribute|
            instance.public_send("#{name}=", attribute)
          end
        end
      end

      delegate :expose, :reset, to: :instance

      # Calls this block after #reset is called on the instance. Used for resetting external collaborators, like Time.zone.
      def resets(&block)
        set_callback :reset, :after, &block
      end

      private
        def generated_attribute_methods
          @generated_attribute_methods ||= Module.new.tap { |mod| include mod }
        end
    end

    attr_accessor :attributes

    def initialize
      @attributes = {}
    end

    # Expose one or more attributes within a block. Old values are returned after the block concludes.
    # Example demonstrating the common use of needing to set Current attributes outside the request-cycle:
    #
    #   class Chat::PublicationJob < ApplicationJob
    #     def perform(attributes, room_number, creator)
    #       Current.expose(person: creator) do
    #         Chat::Publisher.publish(attributes: attributes, room_number: room_number)
    #       end
    #     end
    #   end
    def expose(exposed_attributes)
      old_attributes = compute_attributes(exposed_attributes.keys)
      assign_attributes(exposed_attributes)
      yield
    ensure
      assign_attributes(old_attributes)
    end

    # Reset all attributes. Should be called before and after actions, when used as a per-request singleton.
    def reset
      run_callbacks :reset do
        self.attributes = {}
      end
    end

    private
      def assign_attributes(new_attributes)
        new_attributes.each { |key, value| public_send("#{key}=", value) }
      end

      def compute_attributes(keys)
        keys.collect { |key| [ key, public_send(key) ] }.to_h
      end
  end
end
