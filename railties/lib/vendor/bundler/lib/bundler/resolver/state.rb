module Bundler
  module Resolver
    class State
      include Search::Node, Inspect

      def initialize(depth, engine, path, spec_stack, dep_stack)
        super(depth)
        @engine, @path, @spec_stack, @dep_stack = engine, path, spec_stack, dep_stack
      end
      attr_reader :path

      def logger
        @engine.logger
      end

      def goal_met?
        logger.info "checking if goal is met"
        dump
        no_duplicates?
        all_deps.all? do |dep|
          dependency_satisfied?(dep)
        end
      end

      def no_duplicates?
        names = []
        all_specs.each do |s|
          if names.include?(s.name)
            raise "somehow got duplicates for #{s.name}"
          end
          names << s.name
        end
      end

      def dependency_satisfied?(dep)
        all_specs.any? do |spec|
          spec.satisfies_requirement?(dep)
        end
      end

      def each_possibility(&block)
        index, dep = remaining_deps.first
        if dep
          logger.warn "working on #{dep} for #{spec_name}"
          handle_dep(index, dep, &block)
        else
          logger.warn "no dependencies left for #{spec_name}"
          jump_to_parent(&block)
        end
      end

      def handle_dep(index, dep)
        specs = @engine.source_index.search(dep)

        specs.reverse.each do |s|
          logger.info "attempting with spec: #{s.full_name}"
          new_path = @path + [index]
          new_spec_stack = @spec_stack.dup
          new_dep_stack = @dep_stack.dup

          new_spec_stack[new_path] = s
          new_dep_stack[new_path] = s.runtime_dependencies.sort_by do |dep|
            @engine.source_index.search(dep).size
          end
          yield child(@engine, new_path, new_spec_stack, new_dep_stack)
        end
      end

      def jump_to_parent
        if @path.empty?
          dump
          logger.warn "at the end"
          return
        end

        logger.info "jumping to parent for #{spec_name}"
        new_path = @path[0..-2]
        new_spec_stack = @spec_stack.dup
        new_dep_stack = @dep_stack.dup

        yield child(@engine, new_path, new_spec_stack, new_dep_stack)
      end

      def remaining_deps
        remaining_deps_for(@path)
      end

      def remaining_deps_for(path)
        no_duplicates?
        remaining = []
        @dep_stack[path].each_with_index do |dep,i|
          remaining << [i, dep] unless all_specs.find {|s| s.name == dep.name}
        end
        remaining
      end

      def deps
        @dep_stack[@path]
      end

      def spec
        @spec_stack[@path]
      end

      def spec_name
        @path.empty? ? "<top>" : spec.full_name
      end

      def all_deps
        all_deps = Set.new
        @dep_stack.each_value do |deps|
          all_deps.merge(deps)
        end
        all_deps.to_a
      end

      def all_specs
        @spec_stack.map do |path,spec|
          spec
        end
      end

      def dump(level = Logger::DEBUG)
        logger.add level, "v" * 80
        logger.add level, "path: #{@path.inspect}"
        logger.add level, "deps: (#{deps.size})"
        deps.map do |dep|
          logger.add level, gem_resolver_inspect(dep)
        end
        logger.add level, "remaining_deps: (#{remaining_deps.size})"
        remaining_deps.each do |dep|
          logger.add level, gem_resolver_inspect(dep)
        end
        logger.add level, "dep_stack: "
        @dep_stack.each do |path,deps|
          logger.add level, "#{path.inspect} (#{deps.size})"
          deps.each do |dep|
            logger.add level, "-> #{gem_resolver_inspect(dep)}"
          end
        end
        logger.add level, "spec_stack: "
        @spec_stack.each do |path,spec|
          logger.add level, "#{path.inspect}: #{gem_resolver_inspect(spec)}"
        end
        logger.add level, "^" * 80
      end

      def to_dot
        io = StringIO.new
        io.puts 'digraph deps {'
        io.puts '  fontname = "Courier";'
        io.puts '  mincross = 4.0;'
        io.puts '  ratio = "auto";'
        dump_to_dot(io, "<top>", [])
        io.puts '}'
        io.string
      end

      def dump_to_dot(io, name, path)
        @dep_stack[path].each_with_index do |dep,i|
          new_path = path + [i]
          spec_name = all_specs.find {|x| x.name == dep.name}.full_name
          io.puts '  "%s" -> "%s";' % [name, dep.to_s]
          io.puts '  "%s" -> "%s";' % [dep.to_s, spec_name]
          if @spec_stack.key?(new_path)
            dump_to_dot(io, spec_name, new_path)
          end
        end
      end
    end
  end
end