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
          # don't ever hand out a template without running a stale check
          (new_template = @paths[path]) && new_template.reset_cache_if_stale!
        end
      end

      private
        def register_template_from_file(template_full_file_path)
          if !@paths[relative_path = relative_path_for_template_file(template_full_file_path)] && File.file?(template_full_file_path)
            register_template(ReloadableTemplate.new(relative_path, self))
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

    # remove any compiled methods that look like they might belong to me
    def undef_my_compiled_methods!
      ActionView::Base::CompiledTemplates.public_instance_methods.grep(/#{Regexp.escape(method_name_without_locals)}(?:_locals_)?/).each do |m|
        ActionView::Base::CompiledTemplates.send(:remove_method, m)
      end
    end

  end
end
