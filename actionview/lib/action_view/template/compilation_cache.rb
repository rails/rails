# frozen_string_literal: true

require "digest"

module ActionView
  class Template
    module CompilationCache # :nodoc:
      def self.cache_dir
        if defined?(Bootsnap::CompileCache::Native) && defined?(Bootsnap::CompileCache::ISeq)
          if path = Bootsnap::CompileCache::ISeq.cache_dir
            "#{path}-views"
          end
        end
      end

      def self.fetch(template, source)
        unless directory = cache_dir
          return template.handler.call(template, source)
        end

        unless Ractor.current == Ractor.main
          return template.handler.call(template, source)
        end

        compiler = Compiler.new(template, source)
        Bootsnap::CompileCache::Native.fetch(*arguments(directory, template, source, compiler), nil)
      end

      def self.precompile(template, source)
        unless directory = cache_dir
          raise "views:precompile requires Bootsnap with its compilation cache enabled"
        end

        # Compile outside native precompile, which can suppress callback exceptions.
        storage = Marshal.dump(template.handler.call(template, source))
        compiler = Compiler.new(template, source, storage: storage)
        unless Bootsnap::CompileCache::Native.precompile(*arguments(directory, template, source, compiler))
          raise "Bootsnap could not persist the template cache; check cache permissions and read-only settings"
        end
      end

      def self.arguments(directory, template, source, compiler)
        handler_name = template.handler.is_a?(Module) ? template.handler.name : template.handler.class.name
        digest = Digest::SHA256.hexdigest(Marshal.dump([
          handler_name, Digest::SHA256.digest(source.b), source.encoding.name,
          template.virtual_path, template.format, template.variant, template.strict_locals?,
        ]))
        arguments = ["#{directory}/#{digest}", template.identifier, compiler]
        arguments.insert(1, nil) if Bootsnap::CompileCache::Native.method(:precompile).arity == 4
        arguments
      end
      private_class_method :arguments

      class Compiler
        def initialize(template, source, storage: nil)
          @template = template
          @source = source
          @storage = storage
        end

        def input_to_storage(_input, _path)
          @storage || Marshal.dump(@template.handler.call(@template, @source))
        end

        def storage_to_output(storage, _arguments)
          Marshal.load(storage)
        end

        def input_to_output(_input, _path, _arguments = nil)
          @template.handler.call(@template, @source)
        end
      end
    end
  end
end
