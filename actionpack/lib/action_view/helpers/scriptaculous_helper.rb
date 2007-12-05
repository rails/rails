require 'action_view/helpers/javascript_helper'

module ActionView
  module Helpers
    # Provides a set of helpers for calling Scriptaculous JavaScript 
    # functions, including those which create Ajax controls and visual effects.
    #
    # To be able to use these helpers, you must include the Prototype 
    # JavaScript framework and the Scriptaculous JavaScript library in your 
    # pages. See the documentation for ActionView::Helpers::JavaScriptHelper
    # for more information on including the necessary JavaScript.
    #
    # The Scriptaculous helpers' behavior can be tweaked with various options.
    # See the documentation at http://script.aculo.us for more information on
    # using these helpers in your application.
    module ScriptaculousHelper
      unless const_defined? :TOGGLE_EFFECTS
        TOGGLE_EFFECTS = [:toggle_appear, :toggle_slide, :toggle_blind]
      end
      
      # Returns a JavaScript snippet to be used on the Ajax callbacks for
      # starting visual effects.
      #
      # Example:
      #   <%= link_to_remote "Reload", :update => "posts", 
      #         :url => { :action => "reload" }, 
      #         :complete => visual_effect(:highlight, "posts", :duration => 0.5)
      #
      # If no element_id is given, it assumes "element" which should be a local
      # variable in the generated JavaScript execution context. This can be 
      # used for example with drop_receiving_element:
      #
      #   <%= drop_receiving_element (...), :loading => visual_effect(:fade) %>
      #
      # This would fade the element that was dropped on the drop receiving 
      # element.
      #
      # For toggling visual effects, you can use :toggle_appear, :toggle_slide, and
      # :toggle_blind which will alternate between appear/fade, slidedown/slideup, and
      # blinddown/blindup respectively.
      #
      # You can change the behaviour with various options, see
      # http://script.aculo.us for more documentation.
      def visual_effect(name, element_id = false, js_options = {})
        element = element_id ? element_id.to_json : "element"
        
        js_options[:queue] = if js_options[:queue].is_a?(Hash)
          '{' + js_options[:queue].map {|k, v| k == :limit ? "#{k}:#{v}" : "#{k}:'#{v}'" }.join(',') + '}'
        elsif js_options[:queue]
          "'#{js_options[:queue]}'"
        end if js_options[:queue]
        
        [:endcolor, :direction, :startcolor, :scaleMode, :restorecolor].each do |option|
          js_options[option] = "'#{js_options[option]}'" if js_options[option]
        end

        if TOGGLE_EFFECTS.include? name.to_sym
          "Effect.toggle(#{element},'#{name.to_s.gsub(/^toggle_/,'')}',#{options_for_javascript(js_options)});"
        else
          "new Effect.#{name.to_s.camelize}(#{element},#{options_for_javascript(js_options)});"
        end
      end
      
      # Makes the element with the DOM ID specified by +element_id+ sortable
      # by drag-and-drop and make an Ajax call whenever the sort order has
      # changed. By default, the action called gets the serialized sortable
      # element as parameters.
      #
      # Example:
      #   <%= sortable_element("my_list", :url => { :action => "order" }) %>
      #
      # In the example, the action gets a "my_list" array parameter 
      # containing the values of the ids of elements the sortable consists 
      # of, in the current order.
      #
      # Important: For this to work, the sortable elements must have id
      # attributes in the form "string_identifier". For example, "item_1". Only
      # the identifier part of the id attribute will be serialized.
      # 
      # Additional +options+ are:
      #
      # <tt>:format</tt>::               A regular expression to determine what to send
      #                                  as the serialized id to the server (the default
      #                                  is <tt>/^[^_]*_(.*)$/</tt>).
      #                                  
      # <tt>:constraint</tt>::           Whether to constrain the dragging to either <tt>:horizontal</tt>
      #                                  or <tt>:vertical</tt> (or false to make it unconstrained).
      #                                   
      # <tt>:overlap</tt>::              Calculate the item overlap in the <tt>:horizontal</tt> or 
      #                                  <tt>:vertical</tt> direction.
      #                                   
      # <tt>:tag</tt>::                  Which children of the container element to treat as
      #                                  sortable (default is <tt>li</tt>).
      #                                  
      # <tt>:containment</tt>::          Takes an element or array of elements to treat as
      #                                  potential drop targets (defaults to the original
      #                                  target element).
      #                                  
      # <tt>:only</tt>::                 A CSS class name or arry of class names used to filter
      #                                  out child elements as candidates.
      #                                  
      # <tt>:scroll</tt>::               Determines whether to scroll the list during drag
      #                                  operationsif the list runs past the visual border.
      #                                  
      # <tt>:tree</tt>::                 Determines whether to treat nested lists as part of the
      #                                  main sortable list. This means that you can create multi-
      #                                  layer lists, and not only sort items at the same level,
      #                                  but drag and sort items between levels.
      #                                  
      # <tt>:hoverclass</tt>::           If set, the Droppable will have this additional CSS class
      #                                  when an accepted Draggable is hovered over it.                         
      #                                 
      # <tt>:handle</tt>::               Sets whether the element should only be draggable by an
      #                                  embedded handle. The value may be a string referencing a
      #                                  CSS class value (as of script.aculo.us V1.5). The first
      #                                  child/grandchild/etc. element found within the element
      #                                  that has this CSS class value will be used as the handle.
      #
      # <tt>:ghosting</tt>::             Clones the element and drags the clone, leaving the original
      #                                  in place until the clone is dropped (defaut is <tt>false</tt>).
      #       
      # <tt>:dropOnEmpty</tt>::          If set to true, the Sortable container will be made into
      #                                  a Droppable, that can receive a Draggable (as according to
      #                                  the containment rules) as a child element when there are no
      #                                  more elements inside (defaut is <tt>false</tt>).
      #       
      # <tt>:onChange</tt>::             Called whenever the sort order changes while dragging. When
      #                                  dragging from one Sortable to another, the callback is
      #                                  called once on each Sortable. Gets the affected element as
      #                                  its parameter.
      #                                 
      # <tt>:onUpdate</tt>::             Called when the drag ends and the Sortable's order is
      #                                  changed in any way. When dragging from one Sortable to
      #                                  another, the callback is called once on each Sortable. Gets
      #                                  the container as its parameter.
      #                                                                                         
      # See http://script.aculo.us for more documentation.
      def sortable_element(element_id, options = {})
        javascript_tag(sortable_element_js(element_id, options).chop!)
      end
      
      def sortable_element_js(element_id, options = {}) #:nodoc:
        options[:with]     ||= "Sortable.serialize(#{element_id.to_json})"
        options[:onUpdate] ||= "function(){" + remote_function(options) + "}"
        options.delete_if { |key, value| PrototypeHelper::AJAX_OPTIONS.include?(key) }
  
        [:tag, :overlap, :constraint, :handle].each do |option|
          options[option] = "'#{options[option]}'" if options[option]
        end
  
        options[:containment] = array_or_string_for_javascript(options[:containment]) if options[:containment]
        options[:only] = array_or_string_for_javascript(options[:only]) if options[:only]
  
        %(Sortable.create(#{element_id.to_json}, #{options_for_javascript(options)});)
      end

      # Makes the element with the DOM ID specified by +element_id+ draggable.
      #
      # Example:
      #   <%= draggable_element("my_image", :revert => true)
      # 
      # You can change the behaviour with various options, see
      # http://script.aculo.us for more documentation.
      def draggable_element(element_id, options = {})
        javascript_tag(draggable_element_js(element_id, options).chop!)
      end
      
      def draggable_element_js(element_id, options = {}) #:nodoc:
        %(new Draggable(#{element_id.to_json}, #{options_for_javascript(options)});)
      end

      # Makes the element with the DOM ID specified by +element_id+ receive
      # dropped draggable elements (created by draggable_element).
      # and make an AJAX call  By default, the action called gets the DOM ID 
      # of the element as parameter.
      #
      # Example:
      #   <%= drop_receiving_element("my_cart", :url => 
      #     { :controller => "cart", :action => "add" }) %>
      #
      # You can change the behaviour with various options, see
      # http://script.aculo.us for more documentation.
      def drop_receiving_element(element_id, options = {})
        javascript_tag(drop_receiving_element_js(element_id, options).chop!)
      end
      
      def drop_receiving_element_js(element_id, options = {}) #:nodoc:
        options[:with]     ||= "'id=' + encodeURIComponent(element.id)"
        options[:onDrop]   ||= "function(element){" + remote_function(options) + "}"
        options.delete_if { |key, value| PrototypeHelper::AJAX_OPTIONS.include?(key) }

        options[:accept] = array_or_string_for_javascript(options[:accept]) if options[:accept]    
        options[:hoverclass] = "'#{options[:hoverclass]}'" if options[:hoverclass]
        
        %(Droppables.add(#{element_id.to_json}, #{options_for_javascript(options)});)
      end
    end
  end
end
