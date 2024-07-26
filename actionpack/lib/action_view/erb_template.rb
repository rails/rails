require 'erb'
require 'action_view/abstract_template'

# Action View templates are written using a mixture of HTML and eRuby tags. eRuby is short for embedded Ruby and that's pretty
# much all the magic there is to it. Plain Ruby inserted into HTML (or XML or something else). You trigger eRuby by using embeddings
# such as <% %> and <%= %>. The difference is whether you want output or not. Consider the following loop for names:
#
#   <b>Names of all the people</b>
#   <% for person in @people %>
#     Name: <%= person.name %><br/>
#   <% end %>
#
# The loop is setup in regular embedding tags (<% %>) and the name is written using the output embedding tag (<%= %>). Note that this
# is not just a usage suggestion. Regular output functions like print or puts won't work with eRuby templates. So this would be wrong:
#
#   Hi, Mr. <% puts "Frodo" %>
#
# == Using sub templates
#
# Using sub templates allows you to sidestep tedious replication and extract common display structures in shared templates. The
# classic example is the use of a header and footer (even though the Action Pack-way would be to use Layouts):
#
#   <%= render "shared/header" %>
#   Something really specific and terrific
#   <%= render "shared/footer" %>
#
# As you see, we use the output embeddings for the render methods. The render call itself will just return a string holding the
# result of the rendering. The output embedding writes it to the current template.
#
# But you don't have to restrict yourself to static includes. Templates can share variables amongst themselves by using instance
# variables defined in using the regular embedding tags. Like this:
#
#   <% @page_title = "A Wonderful Hello" %>
#   <%= render "shared/header" %>
#
# Now the header can pick up on the @page_title variable and use it for outputting a title tag:
#
#    <title><%= @page_title %></title>
#
# == Other template engines
#
# The ERbTemplate is the default Action View class used by the Action Controller. If you want to use a different
# class, you'll need to implement this interface, and use the Base.template_class=. There is already one other implementation 
# available. That's the ErubyTemplate, which is functionally identical to the default ERbTemplate, but uses the C-version of eRuby.
module ActionView
  class ERbTemplate < AbstractTemplate #:nodoc:
    include ERB::Util

    def render_template(template)
      @assigns.each { |key, value| instance_variable_set "@#{key}", value }
      template_render(template, binding)
    end
    
    def file_exists?(template_path)
      FileTest.exists?(full_template_path(template_path))
    end

    private
      def full_template_path(template_path)
        "#{@base_path}/#{template_path}.#{@template_extension}"
      end
    
      def read_template_file(template_path)
        IO.readlines(template_path).join
      end
      
      def template_render(template, binding)
        ERB.new(template).result(binding)
      end
  end
end