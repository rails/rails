module ActionController #:nodoc:
  module RescueWithHelper

    def rescue_with_handler(exception)
      if ((exception.class == ActionView::TemplateError) &&
        (orig_exception = exception.original_exception) &&
        (orig_handler = handler_for_rescue(orig_exception)))
        exception = orig_exception
      end
      super(exception)
    end

  end
end
