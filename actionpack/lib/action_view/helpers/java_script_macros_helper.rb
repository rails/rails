require 'action_view/helpers/tag_helper'

module ActionView
  module Helpers
    # Provides a set of helpers for creating JavaScript macros that rely on and often bundle methods from JavaScriptHelper into
    # larger units. These macros also rely on counterparts in the controller that provide them with their backing. The in-place
    # editing relies on ActionController::Base.in_place_edit_for and the autocompletion relies on 
    # ActionController::Base.auto_complete_for.
    module JavaScriptMacrosHelper      
      # DEPRECATION WARNING: This method will become a separate plugin when Rails 2.0 ships.
      #
      # Adds AJAX autocomplete functionality to the text input field with the 
      # DOM ID specified by +field_id+.
      #
      # This function expects that the called action returns an HTML <ul> list,
      # or nothing if no entries should be displayed for autocompletion.
      #
      # You'll probably want to turn the browser's built-in autocompletion off,
      # so be sure to include an <tt>autocomplete="off"</tt> attribute with your text
      # input field.
      #
      # The autocompleter object is assigned to a Javascript variable named <tt>field_id</tt>_auto_completer.
      # This object is useful if you for example want to trigger the auto-complete suggestions through
      # other means than user input (for that specific case, call the <tt>activate</tt> method on that object). 
      # 
      # Required +options+ are:
      # <tt>:url</tt>::                  URL to call for autocompletion results
      #                                  in url_for format.
      # 
      # Addtional +options+ are:
      # <tt>:update</tt>::               Specifies the DOM ID of the element whose 
      #                                  innerHTML should be updated with the autocomplete
      #                                  entries returned by the AJAX request. 
      #                                  Defaults to <tt>field_id</tt> + '_auto_complete'
      # <tt>:with</tt>::                 A JavaScript expression specifying the
      #                                  parameters for the XMLHttpRequest. This defaults
      #                                  to 'fieldname=value'.
      # <tt>:frequency</tt>::            Determines the time to wait after the last keystroke
      #                                  for the AJAX request to be initiated.
      # <tt>:indicator</tt>::            Specifies the DOM ID of an element which will be
      #                                  displayed while autocomplete is running.
      # <tt>:tokens</tt>::               A string or an array of strings containing
      #                                  separator tokens for tokenized incremental 
      #                                  autocompletion. Example: <tt>:tokens => ','</tt> would
      #                                  allow multiple autocompletion entries, separated
      #                                  by commas.
      # <tt>:min_chars</tt>::            The minimum number of characters that should be
      #                                  in the input field before an Ajax call is made
      #                                  to the server.
      # <tt>:on_hide</tt>::              A Javascript expression that is called when the
      #                                  autocompletion div is hidden. The expression
      #                                  should take two variables: element and update.
      #                                  Element is a DOM element for the field, update
      #                                  is a DOM element for the div from which the
      #                                  innerHTML is replaced.
      # <tt>:on_show</tt>::              Like on_hide, only now the expression is called
      #                                  then the div is shown.
      # <tt>:after_update_element</tt>:: A Javascript expression that is called when the
      #                                  user has selected one of the proposed values. 
      #                                  The expression should take two variables: element and value.
      #                                  Element is a DOM element for the field, value
      #                                  is the value selected by the user.
      # <tt>:select</tt>::               Pick the class of the element from which the value for 
      #                                  insertion should be extracted. If this is not specified,
      #                                  the entire element is used.
      # <tt>:method</tt>::               Specifies the HTTP verb to use when the autocompletion
      #                                  request is made. Defaults to POST.
      def auto_complete_field(field_id, options = {})
        function =  "var #{field_id}_auto_completer = new Ajax.Autocompleter("
        function << "'#{field_id}', "
        function << "'" + (options[:update] || "#{field_id}_auto_complete") + "', "
        function << "'#{url_for(options[:url])}'"
        
        js_options = {}
        js_options[:tokens] = array_or_string_for_javascript(options[:tokens]) if options[:tokens]
        js_options[:callback]   = "function(element, value) { return #{options[:with]} }" if options[:with]
        js_options[:indicator]  = "'#{options[:indicator]}'" if options[:indicator]
        js_options[:select]     = "'#{options[:select]}'" if options[:select]
        js_options[:paramName]  = "'#{options[:param_name]}'" if options[:param_name]
        js_options[:frequency]  = "#{options[:frequency]}" if options[:frequency]
        js_options[:method]     = "'#{options[:method].to_s}'" if options[:method]

        { :after_update_element => :afterUpdateElement, 
          :on_show => :onShow, :on_hide => :onHide, :min_chars => :minChars }.each do |k,v|
          js_options[v] = options[k] if options[k]
        end

        function << (', ' + options_for_javascript(js_options) + ')')

        javascript_tag(function)
      end
      
      # DEPRECATION WARNING: This method will become a separate plugin when Rails 2.0 ships.
      #
      # Use this method in your view to generate a return for the AJAX autocomplete requests.
      #
      # Example action:
      #
      #   def auto_complete_for_item_title
      #     @items = Item.find(:all, 
      #       :conditions => [ 'LOWER(description) LIKE ?', 
      #       '%' + request.raw_post.downcase + '%' ])
      #     render :inline => "<%= auto_complete_result(@items, 'description') %>"
      #   end
      #
      # The auto_complete_result can of course also be called from a view belonging to the 
      # auto_complete action if you need to decorate it further.
      def auto_complete_result(entries, field, phrase = nil)
        return unless entries
        items = entries.map { |entry| content_tag("li", phrase ? highlight(entry[field], phrase) : h(entry[field])) }
        content_tag("ul", items.uniq)
      end
      
      # DEPRECATION WARNING: This method will become a separate plugin when Rails 2.0 ships.
      #
      # Wrapper for text_field with added AJAX autocompletion functionality.
      #
      # In your controller, you'll need to define an action called
      # auto_complete_for to respond the AJAX calls,
      # 
      # See the RDoc on ActionController::Macros::AutoComplete to learn more about this.
      def text_field_with_auto_complete(object, method, tag_options = {}, completion_options = {})
        (completion_options[:skip_style] ? "" : auto_complete_stylesheet) +
        text_field(object, method, tag_options) +
        content_tag("div", "", :id => "#{object}_#{method}_auto_complete", :class => "auto_complete") +
        auto_complete_field("#{object}_#{method}", { :url => { :action => "auto_complete_for_#{object}_#{method}" } }.update(completion_options))
      end

      private
        def auto_complete_stylesheet
          content_tag('style', <<-EOT, :type => Mime::CSS)
            div.auto_complete {
              width: 350px;
              background: #fff;
            }
            div.auto_complete ul {
              border:1px solid #888;
              margin:0;
              padding:0;
              width:100%;
              list-style-type:none;
            }
            div.auto_complete ul li {
              margin:0;
              padding:3px;
            }
            div.auto_complete ul li.selected {
              background-color: #ffb;
            }
            div.auto_complete ul strong.highlight {
              color: #800; 
              margin:0;
              padding:0;
            }
          EOT
        end

    end
  end
end
