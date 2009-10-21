module ActionMailer
  # TODO Remove this module all together in a next release. Ensure that super
  # hooks in ActionMailer::Base are removed as well.
  module DeprecatedBody
    def self.included(base)
      base.class_eval do
        # Define the body of the message. This is either a Hash (in which case it
        # specifies the variables to pass to the template when it is rendered),
        # or a string, in which case it specifies the actual text of the message.
        adv_attr_accessor :body
      end
    end

    def initialize_defaults(method_name)
      @body ||= {}
    end

    def create_parts
      if String === @body
        ActiveSupport::Deprecation.warn('body is deprecated. To set the body with a text ' <<
                                        'call render(:text => "body").', caller[0,10])
        self.response_body = @body
      elsif @body.is_a?(Hash) && !@body.empty?
        ActiveSupport::Deprecation.warn('body is deprecated. To set assigns simply ' << 
                                        'use instance variables', caller[0,10])
        @body.each { |k, v| instance_variable_set(:"@#{k}", v) }
      end
    end

    def render(*args)
      options = args.last.is_a?(Hash) ? args.last : {}
      if options[:body]
        ActiveSupport::Deprecation.warn(':body is deprecated. To set assigns simply ' << 
                                        'use instance variables', caller[0,1])

        options.delete(:body).each do |k, v|
          instance_variable_set(:"@#{k}", v)
        end
      end

      super
    end
  end
end
