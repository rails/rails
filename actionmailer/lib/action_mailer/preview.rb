# frozen_string_literal: true

require "active_support/descendants_tracker"

module ActionMailer
  module Previews #:nodoc:
    extend ActiveSupport::Concern

    included do
      # Set the location of mailer previews through app configuration:
      #
      #     config.action_mailer.preview_path = "#{Rails.root}/lib/mailer_previews"
      #
      mattr_accessor :preview_path, instance_writer: false

      # Enable or disable mailer previews through app configuration:
      #
      #     config.action_mailer.show_previews = true
      #
      # Defaults to +true+ for development environment
      #
      mattr_accessor :show_previews, instance_writer: false

      # :nodoc:
      mattr_accessor :preview_interceptors, instance_writer: false, default: [ActionMailer::InlinePreviewInterceptor]
    end

    module ClassMethods
      # Register one or more Interceptors which will be called before mail is previewed.
      def register_preview_interceptors(*interceptors)
        interceptors.flatten.compact.each { |interceptor| register_preview_interceptor(interceptor) }
      end

      # Unregister one or more previously registered Interceptors.
      def unregister_preview_interceptors(*interceptors)
        interceptors.flatten.compact.each { |interceptor| unregister_preview_interceptor(interceptor) }
      end

      # Register an Interceptor which will be called before mail is previewed.
      # Either a class or a string can be passed in as the Interceptor. If a
      # string is passed in it will be constantized.
      def register_preview_interceptor(interceptor)
        preview_interceptor = interceptor_class_for(interceptor)

        unless preview_interceptors.include?(preview_interceptor)
          preview_interceptors << preview_interceptor
        end
      end

      # Unregister a previously registered Interceptor.
      # Either a class or a string can be passed in as the Interceptor. If a
      # string is passed in it will be constantized.
      def unregister_preview_interceptor(interceptor)
        preview_interceptors.delete(interceptor_class_for(interceptor))
      end

      private
        def interceptor_class_for(interceptor)
          case interceptor
          when String, Symbol
            interceptor.to_s.camelize.constantize
          else
            interceptor
          end
        end
    end
  end

  class Preview
    extend ActiveSupport::DescendantsTracker

    attr_reader :params

    def initialize(params = {})
      @params = params
    end

    class << self
      # Returns all mailer preview classes.
      def all
        load_previews if descendants.empty?
        descendants
      end

      # Returns the mail object for the given email name. The registered preview
      # interceptors will be informed so that they can transform the message
      # as they would if the mail was actually being delivered.
      def call(email, params = {})
        preview = new(params)
        message = preview.public_send(email)
        inform_preview_interceptors(message)
        message
      end

      # Returns all of the available email previews.
      def emails
        public_instance_methods(false).map(&:to_s).sort
      end

      # Returns +true+ if the email exists.
      def email_exists?(email)
        emails.include?(email)
      end

      # Returns +true+ if the preview exists.
      def exists?(preview)
        all.any? { |p| p.preview_name == preview }
      end

      # Find a mailer preview by its underscored class name.
      def find(preview)
        all.find { |p| p.preview_name == preview }
      end

      # Returns the underscored name of the mailer preview without the suffix.
      def preview_name
        name.sub(/Preview$/, "").underscore
      end

      private
        def load_previews
          if preview_path
            Dir["#{preview_path}/**/*_preview.rb"].sort.each { |file| require_dependency file }
          end
        end

        def preview_path
          Base.preview_path
        end

        def show_previews
          Base.show_previews
        end

        def inform_preview_interceptors(message)
          Base.preview_interceptors.each do |interceptor|
            interceptor.previewing_email(message)
          end
        end
    end
  end
end
