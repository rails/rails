module ActionController
  module UrlFor
    extend ActiveSupport::Concern

    include RackConvenience

    def process_action(*)
      initialize_current_url
      super
    end

    def initialize_current_url
      @url = UrlRewriter.new(request, params.clone)
    end

    # Overwrite to implement a number of default options that all url_for-based methods will use. The default options should come in
    # the form of a hash, just like the one you would use for url_for directly. Example:
    #
    #   def default_url_options(options)
    #     { :project => @project.active? ? @project.url_name : "unknown" }
    #   end
    #
    # As you can infer from the example, this is mostly useful for situations where you want to centralize dynamic decisions about the
    # urls as they stem from the business domain. Please note that any individual url_for call can always override the defaults set
    # by this method.
    def default_url_options(options = nil)
    end

    def rewrite_options(options) #:nodoc:
      if defaults = default_url_options(options)
        defaults.merge(options)
      else
        options
      end
    end

    def url_for(options = {})
      options ||= {}
      case options
        when String
          options
        when Hash
          @url.rewrite(rewrite_options(options))
        else
          polymorphic_url(options)
      end
    end
  end
end
