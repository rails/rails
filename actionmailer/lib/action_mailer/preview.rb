require 'active_support/descendants_tracker'

module ActionMailer
  module Previews #:nodoc:
    extend ActiveSupport::Concern

    included do
      # Set the location of mailer previews through app configuration:
      #
      #     config.action_mailer.preview_path = "#{Rails.root}/lib/mailer_previews"
      #
      class_attribute :preview_path, instance_writer: false
    end
  end

  class Preview
    extend ActiveSupport::DescendantsTracker

    class << self
      # Returns all mailer preview classes
      def all
        load_previews if descendants.empty?
        descendants
      end

      # Returns the mail object for the given email name
      def call(email)
        preview = self.new
        preview.public_send(email)
      end

      # Returns all of the available email previews
      def emails
        public_instance_methods(false).map(&:to_s).sort
      end

      # Returns true if the email exists
      def email_exists?(email)
        emails.include?(email)
      end

      # Returns true if the preview exists
      def exists?(preview)
        all.any?{ |p| p.preview_name == preview }
      end

      # Find a mailer preview by its underscored class name
      def find(preview)
        all.find{ |p| p.preview_name == preview }
      end

      # Returns the underscored name of the mailer preview without the suffix
      def preview_name
        name.sub(/Preview$/, '').underscore
      end

      protected
        def load_previews #:nodoc:
          if preview_path?
            Dir["#{preview_path}/**/*_preview.rb"].each{ |file| require_dependency file }
          end
        end

        def preview_path #:nodoc:
          Base.preview_path
        end

        def preview_path? #:nodoc:
          Base.preview_path?
        end
    end
  end
end
