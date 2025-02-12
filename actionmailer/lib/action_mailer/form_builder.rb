# frozen_string_literal: true

module ActionMailer
  # = Action Mailer Form Builder
  #
  # Override the default form builder for all views rendered by this
  # mailer and any of its descendants. Accepts a subclass of
  # ActionView::Helpers::FormBuilder.
  #
  # While emails typically will not include forms, this can be used
  # by views that are shared between controllers and mailers.
  #
  # For more information, see +ActionController::FormBuilder+.
  module FormBuilder
    extend ActiveSupport::Concern

    included do
      class_attribute :_default_form_builder, instance_accessor: false
    end

    module ClassMethods
      # Set the form builder to be used as the default for all forms
      # in the views rendered by this mailer and its subclasses.
      #
      # ==== Parameters
      # * <tt>builder</tt> - Default form builder. Accepts a subclass of ActionView::Helpers::FormBuilder
      def default_form_builder(builder)
        self._default_form_builder = builder
      end
    end

    # Default form builder for the mailer
    def default_form_builder
      self.class._default_form_builder
    end
  end
end
