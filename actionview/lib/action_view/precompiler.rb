# frozen_string_literal: true

require "action_view/template_scanner"
require "action_view/controller_scanner"
require "action_view/helper_scanner"

module ActionView
  # = Action View Template Precompiler
  #
  # Eagerly compiles all templates at boot time. This improves cold render times
  # and allows more memory to be shared via copy-on-write on forking web servers
  # like Puma (clustered mode) and Unicorn.
  #
  # The precompiler works by:
  # 1. Scanning all view templates, controllers, and helpers for +render+ calls
  # 2. Extracting the locals passed to each render call
  # 3. Enumerating implicit controller action renders (actions without explicit +render+)
  # 4. Resolving each template via the lookup context
  # 5. Compiling each template by calling +compile!+
  #
  # Mispredicted render calls are harmless — they only waste a small amount of
  # memory by compiling templates that may not be used.
  class Precompiler # :nodoc:
    VIRTUAL_PATH_REGEX = %r{\A(?:(?<prefix>.*)/)?(?<partial>_)?(?<action>[^/.]+)}

    class << self
      def precompile(engines:, controllers:)
        ActiveSupport::Notifications.instrument("precompile_templates.action_view") do |payload|
          precompiler = new(controllers)

          # Scan view directories from all engines and the application
          engines.each do |engine|
            engine.paths["app/views"].existent.each do |view_dir|
              precompiler.scan_view_dir(view_dir)
            end

            engine.paths["app/controllers"].existent.each do |controller_dir|
              precompiler.scan_controller_dir(controller_dir)
            end

            engine.paths["app/helpers"].existent.each do |helper_dir|
              precompiler.scan_helper_dir(helper_dir)
            end
          end

          # Scan additional paths configured by the application
          ActionView.precompile_additional_paths.each do |dir|
            precompiler.scan_ruby_dir(dir)
          end

          # Add implicit controller action renders
          controllers.each do |controller|
            controller.action_methods.each do |action|
              next if action.include?(".")
              precompiler.add_template("#{controller.controller_path}/#{action}")
            end
          end

          payload[:count] = precompiler.run
        end
      end
    end

    def initialize(controllers = [])
      @template_renders = []
      @controllers = controllers
    end

    def scan_view_dir(view_dir)
      return unless File.directory?(view_dir)
      scanner = TemplateScanner.new(view_dir)
      @template_renders.concat(scanner.template_renders)
    end

    def scan_controller_dir(controller_dir)
      return unless File.directory?(controller_dir)
      scanner = ControllerScanner.new(controller_dir)
      @template_renders.concat(scanner.template_renders)
    end

    def scan_helper_dir(helper_dir)
      return unless File.directory?(helper_dir)
      scanner = HelperScanner.new(helper_dir)
      @template_renders.concat(scanner.template_renders)
    end

    def scan_ruby_dir(dir)
      return unless File.directory?(dir)
      scan_view_dir(dir)
      scan_controller_dir(dir)
      scan_helper_dir(dir)
    end

    def add_template(virtual_path, locals = [])
      locals = locals.map(&:to_sym).sort
      @template_renders << [virtual_path, locals]
    end

    def run
      @template_renders.uniq!

      count = 0
      controllers_by_view_paths = group_controllers_by_view_paths

      controllers_by_view_paths.each do |view_paths, controllers|
        lookup_context = LookupContext.new(view_paths)
        view_context_class = controllers.first.view_context_class

        @template_renders.each do |virtual_path, locals|
          templates = find_all_templates(lookup_context, virtual_path, locals)
          templates.each do |template|
            template.send(:compile!, view_context_class)
            count += 1
          end
        end
      end

      count
    end

    private
      def group_controllers_by_view_paths
        @controllers.group_by { |c| c._view_paths }
      end

      def find_all_templates(lookup_context, virtual_path, locals)
        match = virtual_path.match(VIRTUAL_PATH_REGEX)
        return [] unless match

        action = match[:action]
        prefix = match[:prefix] ? [match[:prefix]] : []
        partial = !!match[:partial]

        lookup_context.find_all(action, prefix, partial, locals)
      rescue ActionView::MissingTemplate
        []
      end
  end
end
