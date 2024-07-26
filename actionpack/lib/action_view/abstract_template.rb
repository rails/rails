require 'erb'

module ActionView
  class ActionViewError < Exception #:nodoc:
  end

  class AbstractTemplate
    attr_reader :first_render
    attr_accessor :base_path, :assigns, :template_extension
    attr_accessor :controller

    def self.load_helpers(helper_dir)
      Dir.foreach(helper_dir) do |helper_file| 
        next unless helper_file =~ /_helper.rb$/
        require helper_dir + helper_file
        helper_module_name = helper_file.capitalize.gsub(/_([a-z])/) { |m| $1.capitalize }[0..-4]

        class_eval("include ActionView::Helpers::#{helper_module_name}") if Helpers.const_defined?(helper_module_name)
      end
    end

    def initialize(base_path = nil, assigns_for_first_render = {}, controller = nil)
      @base_path, @template_extension, @assigns = base_path, template_extension, assigns_for_first_render
      @controller = controller
      @template_extension = "rhtml"
    end

    def render_file(template_path, use_full_path = true, local_assigns = {})
      @first_render      = template_path if @first_render.nil?
      template_file_name = use_full_path ? full_template_path(template_path) : template_path
      template_source    = read_template_file(template_file_name)

      begin
        render_template(template_source, local_assigns)
      rescue Exception => e
        if TemplateError === e
          e.sub_template_of(template_file_name)
          raise e
        else
          raise TemplateError.new(@base_path, template_file_name, @assigns, template_source, e)
        end
      end
    end
    
    def render(template_path, local_assigns = {})
      render_file(template_path, true, local_assigns)
    end
    
    def render_partial(partial_name, object = nil, local_assigns = {})
      object ||= controller.instance_variable_get("@#{partial_name}")
      render("#{controller.send(:controller_name)}/_#{partial_name}", { partial_name => object }.merge(local_assigns))
    end
    
    def render_collection_of_partials(partial_name, collection, partial_spacer_template = nil)
      collection_of_partials = collection.collect { |element| render_partial(partial_name, element) }
      partial_spacer_template ? 
        collection_of_partials.join(render("#{controller.send(:controller_name)}/_#{partial_spacer_template}")) : 
        collection_of_partials
    end
    
    # Must be implemented by concrete template class
    def render_template(template) end
    def file_exists?(template_path) end

    private
      def full_template_path(template_path) end
      def read_template_file(template_path) end
  end
end

require 'action_view/template_error'