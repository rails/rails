require 'eruby'

module ActionView
  class ErubyTemplate < ERbTemplate #:nodoc:
    private
      def template_render(template, binding)
        r, w = IO.pipe
        $stdout = w
        eval(ERuby::Compiler.new.compile_string(template), binding)
        $stdout = STDOUT
        w.close
        output = r.read
        r.close
        return output
      end
  end
end