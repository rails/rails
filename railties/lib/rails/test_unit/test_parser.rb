# frozen_string_literal: true

require "ripper"

module Rails
  module TestUnit
    # Parse a test file to extract the line ranges of all tests in both
    # method-style (def test_foo) and declarative-style (test "foo" do)
    class TestParser < Ripper # :nodoc:
      # Helper to translate a method object into the path and line range where
      # the method was defined.
      def self.definition_for(method_obj)
        path, begin_line = method_obj.source_location
        begins_to_ends = new(File.read(path), path).parse
        return unless end_line = begins_to_ends[begin_line]
        [path, (begin_line..end_line)]
      end

      def initialize(*)
        # A hash mapping the 1-indexed line numbers that tests start on to where they end.
        @begins_to_ends = {}
        super
      end

      def parse
        super
        @begins_to_ends
      end

      # method test e.g. `def test_some_description`
      # This event's first argument gets the `ident` node containing the method
      # name, which we have overridden to return the line number of the ident
      # instead.
      def on_def(begin_line, *)
        @begins_to_ends[begin_line] = lineno
      end

      # Everything past this point is to support declarative tests, which
      # require more work to get right because of the many different ways
      # methods can be invoked in ruby, all of which are parsed differently.
      #
      # The approach is just to store the current line number when the
      # "test" method is called and pass it up the tree so it's available at
      # the point when we also know the line where the associated block ends.

      def on_method_add_block(begin_line, end_line)
        if begin_line && end_line
          @begins_to_ends[begin_line] = end_line
        end
      end

      def on_command_call(*, begin_lineno, _args)
        begin_lineno
      end

      def first_arg(arg, *)
        arg
      end

      def just_lineno(*)
        lineno
      end

      alias on_method_add_arg first_arg
      alias on_command first_arg
      alias on_stmts_add first_arg
      alias on_arg_paren first_arg
      alias on_bodystmt first_arg

      alias on_ident just_lineno
      alias on_do_block just_lineno
      alias on_stmts_new just_lineno
      alias on_brace_block just_lineno

      def on_args_new
        []
      end

      def on_args_add(parts, part)
        parts << part
      end

      def on_args_add_block(args, *rest)
        args.first
      end
    end
  end
end
