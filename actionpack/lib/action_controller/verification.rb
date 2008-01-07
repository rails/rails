module ActionController #:nodoc:
  module Verification #:nodoc:
    def self.included(base) #:nodoc:
      base.extend(ClassMethods)
    end

    # This module provides a class-level method for specifying that certain
    # actions are guarded against being called without certain prerequisites
    # being met. This is essentially a special kind of before_filter.
    #
    # An action may be guarded against being invoked without certain request
    # parameters being set, or without certain session values existing.
    #
    # When a verification is violated, values may be inserted into the flash, and
    # a specified redirection is triggered. If no specific action is configured,
    # verification failures will by default result in a 400 Bad Request response.
    #
    # Usage:
    #
    #   class GlobalController < ActionController::Base
    #     # Prevent the #update_settings action from being invoked unless
    #     # the 'admin_privileges' request parameter exists. The
    #     # settings action will be redirected to in current controller
    #     # if verification fails.
    #     verify :params => "admin_privileges", :only => :update_post,
    #            :redirect_to => { :action => "settings" }
    #
    #     # Disallow a post from being updated if there was no information
    #     # submitted with the post, and if there is no active post in the
    #     # session, and if there is no "note" key in the flash. The route
    #     # named category_url will be redirected to if verification fails.
    #
    #     verify :params => "post", :session => "post", "flash" => "note",
    #            :only => :update_post,
    #            :add_flash => { "alert" => "Failed to create your message" },
    #            :redirect_to => :category_url
    #
    # Note that these prerequisites are not business rules. They do not examine 
    # the content of the session or the parameters. That level of validation should
    # be encapsulated by your domain model or helper methods in the controller.
    module ClassMethods
      # Verify the given actions so that if certain prerequisites are not met,
      # the user is redirected to a different action. The +options+ parameter
      # is a hash consisting of the following key/value pairs:
      #
      # <tt>:params</tt>:: 
      #   a single key or an array of keys that must be in the <tt>params</tt> 
      #   hash in order for the action(s) to be safely called.
      # <tt>:session</tt>:: 
      #   a single key or an array of keys that must be in the <tt>session</tt> 
      #   in order for the action(s) to be safely called.
      # <tt>:flash</tt>:: 
      #   a single key or an array of keys that must be in the flash in order 
      #   for the action(s) to be safely called.
      # <tt>:method</tt>:: 
      #   a single key or an array of keys--any one of which must match the 
      #   current request method in order for the action(s) to be safely called. 
      #   (The key should be a symbol: <tt>:get</tt> or <tt>:post</tt>, for 
      #   example.)
      # <tt>:xhr</tt>:: 
      #   true/false option to ensure that the request is coming from an Ajax 
      #   call or not. 
      # <tt>:add_flash</tt>:: 
      #   a hash of name/value pairs that should be merged into the session's 
      #   flash if the prerequisites cannot be satisfied.
      # <tt>:add_headers</tt>:: 
      #   a hash of name/value pairs that should be merged into the response's 
      #   headers hash if the prerequisites cannot be satisfied.
      # <tt>:redirect_to</tt>:: 
      #   the redirection parameters to be used when redirecting if the 
      #   prerequisites cannot be satisfied. You can redirect either to named 
      #   route or to the action in some controller.
      # <tt>:render</tt>:: 
      #   the render parameters to be used when the prerequisites cannot be satisfied.
      # <tt>:only</tt>:: 
      #   only apply this verification to the actions specified in the associated 
      #   array (may also be a single value).
      # <tt>:except</tt>:: 
      #   do not apply this verification to the actions specified in the associated 
      #   array (may also be a single value).
      def verify(options={})
        before_filter :only => options[:only], :except => options[:except] do |c|
          c.send! :verify_action, options
        end
      end
    end

  private

    def verify_action(options) #:nodoc:
      if prereqs_invalid?(options)
        flash.update(options[:add_flash])              if options[:add_flash]
        response.headers.update(options[:add_headers]) if options[:add_headers]
        apply_remaining_actions(options)               unless performed?
      end
    end
    
    def prereqs_invalid?(options) # :nodoc:
      verify_presence_of_keys_in_hash_flash_or_params(options) || 
      verify_method(options) || 
      verify_request_xhr_status(options)
    end
 
    def verify_presence_of_keys_in_hash_flash_or_params(options) # :nodoc:
      [*options[:params] ].find { |v| params[v].nil?  } ||
      [*options[:session]].find { |v| session[v].nil? } ||
      [*options[:flash]  ].find { |v| flash[v].nil?   }
    end
    
    def verify_method(options) # :nodoc:
      [*options[:method]].all? { |v| request.method != v.to_sym } if options[:method]
    end
    
    def verify_request_xhr_status(options) # :nodoc:
      request.xhr? != options[:xhr] unless options[:xhr].nil?
    end
    
    def apply_redirect_to(redirect_to_option) # :nodoc:
      redirect_to_option.is_a?(Symbol) ? self.send!(redirect_to_option) : redirect_to_option
    end
    
    def apply_remaining_actions(options) # :nodoc:
      case
        when options[:render]      ; render(options[:render])
        when options[:redirect_to] ; redirect_to(apply_redirect_to(options[:redirect_to]))
        else head(:bad_request)
      end
    end
  end
end