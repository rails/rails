require File.dirname(__FILE__) + '/tag_helper'

module ActionView
  module Helpers
    # You must call <%= define_javascript_functions %> in your application before using these helpers.
    module JavascriptHelper
      # Returns a link that'll trigger a javascript +function+ using the onclick handler and return false after the fact.
      #
      # Examples:
      #   link_to_function "Greeting", "alert('Hello world!')"
      #   link_to_function(image_tag("delete"), "if confirm('Really?'){ do_delete(); }")
      def link_to_function(name, function, html_options = {})
        content_tag(
          "a", name, 
          html_options.symbolize_keys.merge(:href => "#", :onclick => "#{function}; return false;")
        )
      end

      # Returns a link to a remote action defined by <tt>options[:url]</tt> (using the url_for format) that's called in the background 
      # using XMLHttpRequest. The result of that request can then be inserted into a DOM object who's id can be specified
      # with <tt>options[:update]</tt>. Usually, the result would be a partial prepared by the controller with either render_partial
      # or render_partial_collection. 
      #
      # Examples:
      #  link_to_remote "Delete this post", :update => "posts", :url => { :action => "destroy", :id => post.id }
      #  link_to_remote(image_tag("refresh"), :update => "emails", :url => { :action => "list_emails" })
      #
      # Asynchronous requests may be made by specifying a callback function
      # to invoke when the request finishes.
      #
      # Example:
      #   link_to_remote word,
      #       :url => { :action => "undo", :n => word_counter },
      #       :before => "if(!prepareForUndo()) return false",
      #       :complete => "undoRequestCompleted(request)"
      #
      # The complete list of callbacks that may be specified are:
      #
      # * uninitialized
      # * loading
      # * loaded
      # * interactive
      # * complete
      def link_to_remote(name, options = {}, html_options = {})  
        link_to_function(name, remote_function(options), html_options)
      end

      def form_remote_tag(options = {})
        options[:form] = true

        options[:html] ||= { }
        options[:html][:onsubmit] = "#{remote_function(options)}; return false;"

        tag("form", options[:html], true)
      end

      def define_javascript_functions
    <<-EOF
    <script language="JavaScript">
    /* Convenience form methods */
    Field = {
      clear: function() {
        for(i = 0; i < arguments.length; i++) { o(arguments[i]).value = ''; }
        return true;
      },

      focus: function(id) {
        o(id).focus();
        return true;
      },
      
      present: function() {
        for(i = 0; i < arguments.length; i++) { if (o(arguments[i]).value == '') { return false; } }
        return true;
      }
    }
    
    /* XMLHttpRequest Methods */

    function update_with_response() {
      var container  = o(arguments[0]);
      var url        = arguments[1];
      var parameters = arguments[2];
      var async      = arguments[3];

      if (async) {
        xml_request(url, parameters, true,
          { complete: function(request) {
              container.innerHTML = request.responseText }
          })
      } else {
        container.innerHTML = xml_request(url, parameters);
      }
    }

    function xml_request() {
      var url        = arguments[0];
      var parameters = arguments[1];
      var async      = arguments[2];
      var callbacks  = arguments[3];
      var type       = parameters ? "POST" : "GET";
      
      req = xml_http_request_object();
      req.open(type, url, async);

      if (async) {
        invoke_callback = function(which) {
          if(callbacks && callbacks[which]) callbacks[which](req)
        }

        req.onreadystatechange = function() {
          switch(req.readyState) {
            case 0: invoke_callback('uninitialized'); break
            case 1: invoke_callback('loading'); break
            case 2: invoke_callback('loaded'); break
            case 3: invoke_callback('interactive'); break
            case 4: invoke_callback('complete'); break
          }
        }
      }

      req.send(parameters ? parameters + "&_=" : parameters);
      
      if(!async) return req.responseText;
    }

    function xml_http_request_object() {
      var req = false;
      try {
        req = new ActiveXObject("Msxml2.XMLHTTP");
      } catch (e) {
        try {
          req = new ActiveXObject("Microsoft.XMLHTTP");
        } catch (E) {
          req = false;
        }
      }

      if (!req && typeof XMLHttpRequest!='undefined') {
        req = new XMLHttpRequest();
      }

      return req;
    }


    /* Common methods ------------------------------ */

    function toggle_display_by_id(id) {
      o(id).style.display = (o(id).style.display == "none") ? "" : "none";
    }

    function toggle_display() {
      for(i = 0; i < arguments.length; i++) {
        o(arguments[i]).style.display = (o(arguments[i]).style.display == "none") ? "" : "none";
      }
    }

    function o(id) {
      return document.getElementById(id);
    }


    /* Serialize a form by Sam Stephenson ------------------------------ */

    Form = {
      Serializers: {
        input: function(element) {
          switch (element.type.toLowerCase()) {
            case 'hidden':
            case 'text':
              return Form.Serializers.textarea(element);
            case 'checkbox':  
            case 'radio':
              return Form.Serializers.inputSelector(element);
          }
        },
    
        inputSelector: function(element) {
          if (element.checked)
            return [element.name, element.value];
        },
    
        textarea: function(element) {
          return [element.name, element.value];
        },
    
        select: function(element) {
          var index = element.selectedIndex;
          return [element.name, element.options[index].value];
        }
      },
  
      serialize: function(form) {
        var elements = Form.getFormElements(form);
        var queryComponents = new Array();
    
        for (var i = 0; i < elements.length; i++) {
          var element = elements[i];
          var method = element.tagName.toLowerCase();
      
          var parameter = Form.Serializers[method](element);
          if (parameter) {
            var queryComponent = encodeURIComponent(parameter[0]) + '=' +
                                 encodeURIComponent(parameter[1]);
            queryComponents.push(queryComponent);
          }
        }
    
        return queryComponents.join('&');
      },
  
      getFormElements: function(form) {
        var elements = new Array();
        for (tagName in Form.Serializers) {
          var tagElements = form.getElementsByTagName(tagName);
          for (var j = 0; j < tagElements.length; j++)
            elements.push(tagElements[j]);
        }
        return elements;
      }
    }
    </script>
    EOF
      end

      private
        def build_callbacks(options)
          callbacks = nil
          %w{uninitialized loading loaded interactive complete}.each do |cb|
            cb = cb.to_sym
            if options[cb]
              callbacks ? callbacks << "," : callbacks = "{"
              callbacks <<
                "#{cb}:function(request){#{options[cb].gsub(/"/){'\"'}}}"
            end
          end
          callbacks << "}" if callbacks
          callbacks
        end

        def remote_function(options)
          callbacks = build_callbacks(options)

          function = options[:update] ? 
            "update_with_response('#{options[:update]}', " :
            "xml_request("

          function << "'#{url_for(options[:url])}'"
          function << ', Form.serialize(this)' if options[:form]
          function << ', nil' if !options[:form] && callbacks
          function << ", true, " << callbacks if callbacks
          function << ')'

          function = "#{options[:before]}; #{function}" if options[:before]
          function = "#{function}; #{options[:after]}"  if options[:after]
          function = "if (#{options[:condition]}) { #{function}; }" if options[:condition]
      
          return function
        end
    end
  end
end
