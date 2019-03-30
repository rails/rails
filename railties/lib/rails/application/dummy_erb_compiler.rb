# frozen_string_literal: true

# These classes are used to strip out the ERB configuration
# values so we can evaluate the database.yml without evaluating
# the ERB values.
class DummyERB < ERB # :nodoc:
  def make_compiler(trim_mode)
    DummyCompiler.new trim_mode
  end
end

class DummyCompiler < ERB::Compiler # :nodoc:
  def compile_content(stag, out)
    case stag
    when "<%="
      out.push "_erbout << 'dummy_compiler'"
    end
  end
end
