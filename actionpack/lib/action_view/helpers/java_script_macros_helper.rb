require File.dirname(__FILE__) + '/tag_helper'

module ActionView
  module Helpers
    # Provides a set of helpers for creating JavaScript macros that rely on and often bundle methods from JavaScriptHelper into
    # larger units. These macros also rely on counterparts in the controller that provide them with their backing. The in-place
    # editing relies on ActionController::Base.in_place_edit_for and the autocompletion relies on 
    # ActionController::Base.auto_complete_for.
    module JavaScriptMacrosHelper
      # Makes an HTML element specified by the DOM ID +field_id+ become an in-place
      # editor of a property.
      #
      # A form is automatically created and displayed when the user clicks the element,
      # something like this:
      # <form id="myElement-in-place-edit-form" target="specified url">
      #   <input name="value" text="The content of myElement"/>
      #   <input type="submit" value="ok"/>
      #   <a onclick="javascript to cancel the editing">cancel</a>
      # </form>
      # 
      # The form is serialized and sent to the server using an AJAX call, the action on
      # the server should process the value and return the updated value in the body of
      # the reponse. The element will automatically be updated with the changed value
      # (as returned from the server).
      # 
      # Required +options+ are:
      # <tt>:url</tt>::       Specifies the url where the updated value should
      #                       be sent after the user presses "ok".
      # 
      # Addtional +options+ are:
      # <tt>:rows</tt>::              Number of rows (more than 1 will use a TEXTAREA)
      # <tt>:cancel_text</tt>::       The text on the cancel link. (default: "cancel")
      # <tt>:save_text</tt>::         The text on the save link. (default: "ok")
      # <tt>:external_control</tt>::  The id of an external control used to enter edit mode.
      # <tt>:options</tt>::           Pass through options to the AJAX call (see prototype's Ajax.Updater)
      # <tt>:with</tt>::              JavaScript snippet that should return what is to be sent
      #                               in the AJAX call, +form+ is an implicit parameter
      def in_place_editor(field_id, options = {})
        function =  "new Ajax.InPlaceEditor("
        function << "'#{field_id}', "
        function << "'#{url_for(options[:url])}'"

        js_options = {}
        js_options['cancelText'] = %('#{options[:cancel_text]}') if options[:cancel_text]
        js_options['okText'] = %('#{options[:save_text]}') if options[:save_text]
        js_options['rows'] = options[:rows] if options[:rows]
        js_options['externalControl'] = options[:external_control] if options[:external_control]
        js_options['ajaxOptions'] = options[:options] if options[:options]
        js_options['callback']   = "function(form) { return #{options[:with]} }" if options[:with]
        function << (', ' + options_for_javascript(js_options)) unless js_options.empty?
        
        function << ')'

        javascript_tag(function)
      end
      
      # Renders the value of the specified object and method with in-place editing capabilities.
      #
      # See the RDoc on ActionController::InPlaceEditing to learn more about this.
      def in_place_editor_field(object, method, tag_options = {}, in_place_editor_options = {})
        tag = ::ActionView::Helpers::InstanceTag.new(object, method, self)
        tag_options = {:tag => "span", :id => "#{object}_#{method}_#{tag.object.id}_in_place_editor", :class => "in_place_editor_field"}.merge!(tag_options)
        in_place_editor_options[:url] = in_place_editor_options[:url] || url_for({ :action => "set_#{object}_#{method}", :id => tag.object.id })
        tag.to_content_tag(tag_options.delete(:tag), tag_options) +
        in_place_editor(tag_options[:id], in_place_editor_options)
      end
      
      # Adds AJAX autocomplete functionality to the text input field with the 
      # DOM ID specified by +field_id+.
      #
      # This function expects that the called action returns a HTML <ul> list,
      # or nothing if no entries should be displayed for autocompletion.
      #
      # You'll probably want to turn the browser's built-in autocompletion off,
      # su be sure to include a autocomplete="off" attribute with your text
      # input field.
      # 
      # Required +options+ are:
      # <tt>:url</tt>::       URL to call for autocompletion results
      #                       in url_for format.
      # 
      # Addtional +options+ are:
      # <tt>:update</tt>::    Specifies the DOM ID of the element whose 
      #                       innerHTML should be updated with the autocomplete
      #                       entries returned by the AJAX request. 
      #                       Defaults to field_id + '_auto_complete'
      # <tt>:with</tt>::      A JavaScript expression specifying the
      #                       parameters for the XMLHttpRequest. This defaults
      #                       to 'fieldname=value'.
      # <tt>:indicator</tt>:: Specifies the DOM ID of an element which will be
      #                       displayed while autocomplete is running.
      # <tt>:tokens</tt>::    A string or an array of strings containing
      #                       separator tokens for tokenized incremental 
      #                       autocompletion. Example: <tt>:tokens => ','</tt> would
      #                       allow multiple autocompletion entries, separated
      #                       by commas.
      # <tt>:min_chars</tt>:: The minimum number of characters that should be
      #                       in the input field before an Ajax call is made
      #                       to the server.
      # <tt>:on_hide</tt>::   A Javascript expression that is called when the
      #                       autocompletion div is hidden. The expression
      #                       should take two variables: element and update.
      #                       Element is a DOM element for the field, update
      #                       is a DOM element for the div from which the
      #                       innerHTML is replaced.
      # <tt>:on_show</tt>::   Like on_hide, only now the expression is called
      #                       then the div is shown.
      def auto_complete_field(field_id, options = {})
        function =  "new Ajax.Autocompleter("
        function << "'#{field_id}', "
        function << "'" + (options[:update] || "#{field_id}_auto_complete") + "', "
        function << "'#{url_for(options[:url])}'"
        
        js_options = {}
        js_options[:tokens] = array_or_string_for_javascript(options[:tokens]) if options[:tokens]
        js_options[:callback]   = "function(element, value) { return #{options[:with]} }" if options[:with]
        js_options[:indicator]  = "'#{options[:indicator]}'" if options[:indicator]
        {:on_show => :onShow, :on_hide => :onHide, :min_chars => :min_chars}.each do |k,v|
          js_options[v] = options[k] if options[k]
        end
        function << (', ' + options_for_javascript(js_options) + ')')

        javascript_tag(function)
      end
      
      # Use this method in your view to generate a return for the AJAX autocomplete requests.
      #
      # Example action:
      #
      #   def auto_complete_for_item_title
      #     @items = Item.find(:all, 
      #       :conditions => [ 'LOWER(description) LIKE ?', 
      #       '%' + request.raw_post.downcase + '%' ])
      #     render :inline => '<%= auto_complete_result(@items, 'description') %>'
      #   end
      #
      # The auto_complete_result can of course also be called from a view belonging to the 
      # auto_complete action if you need to decorate it further.
      def auto_complete_result(entries, field, phrase = nil)
        return unless entries
        items = entries.map { |entry| content_tag("li", phrase ? highlight(entry[field], phrase) : h(entry[field])) }
        content_tag("ul", items.uniq)
      end
      
      # Wrapper for text_field with added AJAX autocompletion functionality.
      #
      # In your controller, you'll need to define an action called
      # auto_complete_for_object_method to respond the AJAX calls,
      # 
      # See the RDoc on ActionController::AutoComplete to learn more about this.
      def text_field_with_auto_complete(object, method, tag_options = {}, completion_options = {})
        (completion_options[:skip_style] ? "" : auto_complete_stylesheet) +
        text_field(object, method, tag_options) +
        content_tag("div", "", :id => "#{object}_#{method}_auto_complete", :class => "auto_complete") +
        auto_complete_field("#{object}_#{method}", { :url => { :action => "auto_complete_for_#{object}_#{method}" } }.update(completion_options))
      end
      
      private
        def auto_complete_stylesheet
          content_tag("style", <<-EOT
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
          )
        end
      
    end
  end
end
