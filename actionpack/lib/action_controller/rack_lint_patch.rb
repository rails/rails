# Rack 1.0 does not allow string subclass body. This does not play well with our ActionView::SafeBuffer.
# The next release of Rack will be allowing string subclass body - http://github.com/rack/rack/commit/de668df02802a0335376a81ba709270e43ba9d55
# TODO : Remove this monkey patch after the next release of Rack

module RackLintPatch
  module AllowStringSubclass
    def self.included(base)
      base.send :alias_method, :each, :each_with_hack
    end

    def each_with_hack
      @closed = false

      @body.each { |part|
        assert("Body yielded non-string value #{part.inspect}") {
          part.kind_of?(String)
        }
        yield part
      }

      if @body.respond_to?(:to_path)
        assert("The file identified by body.to_path does not exist") {
          ::File.exist? @body.to_path
        }
      end
    end
  end

  begin
    app = proc {|env| [200, {"Content-Type" => "text/plain", "Content-Length" => "12"}, [Class.new(String).new("Hello World!")]] }
    response = Rack::MockRequest.new(Rack::Lint.new(app)).get('/')
  rescue Rack::Lint::LintError => e
    raise(e) unless e.message =~ /Body yielded non-string value/
    Rack::Lint.send :include, AllowStringSubclass
  end
end
