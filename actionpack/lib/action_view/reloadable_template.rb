module ActionView #:nodoc:
  class ReloadableTemplate < Template

    class TemplateDeleted < ActionView::ActionViewError
    end

    class ReloadablePath < Template::Path

      def initialize(path)
        super
        @paths = {}
        new_request!
      end

      def new_request!
        @disk_cache = {}
      end
      alias_method :load!, :new_request!

      def [](path)
        if found_template = @paths[path]
          begin
            found_template.reset_cache_if_stale!
          rescue TemplateDeleted
            unregister_template(found_template)
            self[path]
          end
        else
          load_all_templates_from_dir(templates_dir_from_path(path))
          @paths[path]
        end
      end

      def register_template_from_file(template_file_path)
        if !@paths[template_relative_path = template_file_path.split("#{@path}/").last] && File.file?(template_file_path)
          register_template(ReloadableTemplate.new(template_relative_path, self))
        end
      end

      def register_template(template)
        template.accessible_paths.each do |path|
          @paths[path] = template
        end
      end

      # remove (probably deleted) template from cache
      def unregister_template(template)
        template.accessible_paths.each do |template_path|
          @paths.delete(template_path) if @paths[template_path] == template
        end
        # fill in any newly created gaps
        @paths.values.uniq.each do |template|
          template.accessible_paths.each {|path| @paths[path] ||= template}
        end
      end

      # load all templates from the directory of the requested template
      def load_all_templates_from_dir(dir)
        # hit disk only once per template-dir/request
        @disk_cache[dir] ||= template_files_from_dir(dir).each {|template_file| register_template_from_file(template_file)}
      end

      def templates_dir_from_path(path)
        dirname = File.dirname(path)
        File.join(@path, dirname == '.' ? '' : dirname)
      end

      # get all the template filenames from the dir
      def template_files_from_dir(dir)
        Dir.glob(File.join(dir, '*'))
      end

    end

    module Unfreezable
      def freeze; self; end
    end

    def initialize(*args)
      super
      @compiled_methods = []
      
      # we don't ever want to get frozen
      extend Unfreezable
    end

    def mtime
      File.mtime(filename)
    end

    attr_accessor :previously_last_modified

    def stale?
      previously_last_modified.nil? || previously_last_modified < mtime
    rescue Errno::ENOENT => e
      undef_my_compiled_methods!
      raise TemplateDeleted
    end

    def reset_cache_if_stale!
      if stale?
        flush_cache 'source', 'compiled_source'
        undef_my_compiled_methods!
        @previously_last_modified = mtime
      end
      self
    end

    def undef_my_compiled_methods!
      @compiled_methods.each {|comp_method| ActionView::Base::CompiledTemplates.send(:remove_method, comp_method)}
      @compiled_methods.clear
    end

    def compile!(render_symbol, local_assigns)
      super
      @compiled_methods << render_symbol
    end

  end
end
