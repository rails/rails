# frozen_string_literal: true

# :markup: markdown

module ActionController # :nodoc:
  module Flash
    extend ActiveSupport::Concern

    included do
      class_attribute :_flash_types, instance_accessor: false, default: []

      delegate :flash, to: :request
      add_flash_types(:alert, :notice)
    end

    module ClassMethods
      # Creates new flash types. You can pass as many types as you want to create
      # flash types other than the default `alert` and `notice` in your controllers
      # and views. For instance:
      #
      #     # in application_controller.rb
      #     class ApplicationController < ActionController::Base
      #       add_flash_types :warning
      #     end
      #
      #     # in your controller
      #     redirect_to user_path(@user), warning: "Incomplete profile"
      #
      #     # in your view
      #     <%= warning %>
      #
      # This method will automatically define a new method for each of the given
      # names, and it will be available in your views.
      def add_flash_types(*types)
        types.each do |type|
          next if _flash_types.include?(type)

          define_method(type) do
            request.flash[type]
          end
          private type
          helper_method(type) if respond_to?(:helper_method)

          self._flash_types += [type]
        end
      end
    end

    private
      def redirect_to(options = {}, response_options_and_flash = {}) # :doc:
        self.class._flash_types.each do |flash_type|
          if type = response_options_and_flash.delete(flash_type)
            flash[flash_type] = type
          end
        end

        if other_flashes = response_options_and_flash.delete(:flash)
          flash.update(other_flashes)
        end

        super(options, response_options_and_flash)
      end
  end
end
