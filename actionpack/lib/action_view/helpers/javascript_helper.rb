require File.dirname(__FILE__) + '/tag_helper'

# You must call <%= define_javascript_functions %> in your application before using these helpers.
module JavascriptTagHelper
  def link_to_display_toggle(name, tags, html_options = {})
    toggle_functions = [ tags ].flatten.collect { |tag| "toggle_display_by_id('#{tag}'); " }.join
    content_tag(
      "a", name, 
      html_options.symbolize_keys.merge(:href => "#", :onclick => "#{toggle_functions}; #{html_options['onclick']}; return false;")
    )
  end
  
  def link_to_function(name, function, html_options = {})
    content_tag(
      "a", name, 
      html_options.symbolize_keys.merge(:href => "#", :onclick => "#{function}; return false;")
    )
  end

  def link_to_remote(name, options = {})  
    link_to_function(name, remote_function(options))
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
/* XMLHttpRequest Methods */

function update_with_response() {
  o(arguments[0]).innerHTML = xml_request(arguments[1], arguments[2]);
}

function xml_request() {
  var url        = arguments[0];
  var parameters = arguments[1];
  var async      = arguments[2];
  var type       = parameters ? "POST" : "GET";

  req = xml_http_request_object();
  req.open(type, url, async);
  req.send(parameters);

  return req.responseText;
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
    def remote_function(options)
      function = options[:update] ? 
        "update_with_response('#{options[:update]}', '#{url_for(options[:url])}'#{', Form.serialize(this)' if options[:form]})" :
        "xml_request('#{url_for(options[:url])}'#{', Form.serialize(this)' if options[:form]})"

      function = "#{options[:before]};#{function}" if options[:before]
      function = "#{function};#{options[:after]}"  if options[:after]
      
      return function
    end
end