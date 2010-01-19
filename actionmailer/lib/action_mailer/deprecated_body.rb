module ActionMailer
  # TODO Remove this module all together in a next release. Ensure that super
  # hooks and @assigns_set in ActionMailer::Base are removed as well.
  module DeprecatedBody
    extend ActionMailer::AdvAttrAccessor

    # Define the body of the message. This is either a Hash (in which case it
    # specifies the variables to pass to the template when it is rendered),
    # or a string, in which case it specifies the actual text of the message.
    adv_attr_accessor :body

    def initialize_defaults(method_name)
      @body ||= {}
    end

    def attachment(params, &block)
      if params[:body]
        ActiveSupport::Deprecation.warn('attachment :body => "string" is deprecated. To set the body of an attachment ' <<
                                        'please use :data instead, like attachment :data => "string"', caller[0,10])
        params[:data] = params.delete(:body)
      end
    end

    def create_parts
      if String === @body && !defined?(@assigns_set)
        ActiveSupport::Deprecation.warn('body(String) is deprecated. To set the body with a text ' <<
                                        'call render(:text => "body")', caller[0,10])
        self.response_body = @body
      elsif self.response_body
        @body = self.response_body
      end
    end

    def render(*args)
      options = args.last.is_a?(Hash) ? args.last : {}
      if options[:body]
        ActiveSupport::Deprecation.warn(':body in render deprecated. Please call body ' <<
                                        'with a hash instead', caller[0,1])

        body options.delete(:body)
      end

      super
    end
  end
end
