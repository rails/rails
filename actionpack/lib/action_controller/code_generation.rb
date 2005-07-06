module ActionController
  module CodeGeneration #:nodoc:
    class GenerationError < StandardError #:nodoc:
    end
  
    class Source #:nodoc:
      attr_reader :lines, :indentation_level
      IndentationString = '  '
      def initialize
        @lines, @indentation_level = [], 0
      end
      def line(line)
        @lines << (IndentationString * @indentation_level + line)
      end
      alias :<< :line
    
      def indent
        @indentation_level += 1
        yield
        ensure
        @indentation_level -= 1
      end
    
      def to_s() lines.join("\n") end
    end

    class CodeGenerator #:nodoc:
      attr_accessor :source, :locals
      def initialize(source = nil)
        @locals = []
        @source = source || Source.new
      end
    
      BeginKeywords = %w(if unless begin until while def).collect {|kw| kw.to_sym}
      ResumeKeywords = %w(elsif else rescue).collect {|kw| kw.to_sym}
      Keywords = BeginKeywords + ResumeKeywords
    
      def method_missing(keyword, *text)
        if Keywords.include? keyword
          if ResumeKeywords.include? keyword
            raise GenerationError, "Can only resume with #{keyword} immediately after an end" unless source.lines.last =~ /^\s*end\s*$/ 
            source.lines.pop # Remove the 'end'
          end
      
          line "#{keyword} #{text.join ' '}"
          begin source.indent { yield(self.dup) }
          ensure line 'end'
          end
        else
          super(keyword, *text)
        end
      end
    
      def line(*args) self.source.line(*args) end
      alias :<< :line
      def indent(*args, &block) source(*args, &block) end
      def to_s() source.to_s end
    
      def share_locals_with(other)
        other.locals = self.locals = (other.locals | locals) 
      end
    
      FieldsToDuplicate = [:locals]
      def dup
        copy = self.class.new(source)
        self.class::FieldsToDuplicate.each do |sym|
          value = self.send(sym)
          value = value.dup unless value.nil? || value.is_a?(Numeric)
          copy.send("#{sym}=", value)
        end
        return copy
      end
    end

    class RecognitionGenerator < CodeGenerator #:nodoc:
      Attributes = [:after, :before, :current, :results, :constants, :depth, :move_ahead, :finish_statement]
      attr_accessor(*Attributes)
      FieldsToDuplicate = CodeGenerator::FieldsToDuplicate + Attributes
    
      def initialize(*args)
        super(*args)
        @after, @before = [], []
        @current = nil
        @results, @constants = {}, {}
        @depth = 0
        @move_ahead = nil
        @finish_statement = Proc.new {|hash_expr| hash_expr}
      end
    
      def if_next_matches(string, &block)
        test = Routing.test_condition(next_segment(true), string)
        self.if(test, &block)
      end
    
      def move_forward(places = 1)
        dup = self.dup
        dup.depth += 1
        dup.move_ahead = places
        yield dup
      end
    
      def next_segment(assign_inline = false, default = nil)
        if locals.include?(segment_name)
          code = segment_name
        else
          code = "#{segment_name} = #{path_name}[#{index_name}]"
          if assign_inline
            code = "(#{code})"
          else
            line(code)
            code = segment_name
          end
        
          locals << segment_name
        end
        code = "(#{code} || #{default.inspect})" if default 
      
        return code.to_s
      end
    
      def segment_name() "segment#{depth}".to_sym end
      def path_name() :path end
      def index_name
        move_ahead, @move_ahead = @move_ahead, nil
        move_ahead ? "index += #{move_ahead}" : 'index'
      end
    
      def continue
        dup = self.dup
        dup.before << dup.current
        dup.current = dup.after.shift
        dup.go
      end
    
      def go
        if current then current.write_recognition(self)
        else self.finish
        end
      end 
    
      def result(key, expression, delay = false)
        unless delay
          line "#{key}_value = #{expression}"
          expression = "#{key}_value"
        end
        results[key] = expression
      end
      def constant_result(key, object)
        constants[key] = object
      end
  
      def finish(ensure_traversal_finished = true)
        pairs = [] 
        (results.keys + constants.keys).uniq.each do |key|
          pairs << "#{key.to_s.inspect} => #{results[key] ? results[key] : constants[key].inspect}"
        end
        hash_expr = "{#{pairs.join(', ')}}"
      
        statement = finish_statement.call(hash_expr)
        if ensure_traversal_finished then self.if("! #{next_segment(true)}") {|gp| gp << statement}
        else self << statement
        end
      end
    end
  
    class GenerationGenerator < CodeGenerator #:nodoc:
      Attributes = [:after, :before, :current, :segments]
      attr_accessor(*Attributes)
      FieldsToDuplicate = CodeGenerator::FieldsToDuplicate + Attributes
    
      def initialize(*args)
        super(*args)
        @after, @before = [], []
        @current = nil
        @segments = []
      end
    
      def hash_name() 'hash' end
      def local_name(key) "#{key}_value" end
    
      def hash_value(key, assign = true, default = nil)
        if locals.include?(local_name(key)) then code = local_name(key)
        else
          code = "hash[#{key.to_sym.inspect}]"
          if assign
            code = "(#{local_name(key)} = #{code})"
            locals << local_name(key)
          end
        end
        code = "(#{code} || (#{default.inspect}))" if default
        return code
      end 
    
      def expire_for_keys(*keys)
        return if keys.empty?
        conds = keys.collect {|key| "expire_on[#{key.to_sym.inspect}]"}
        line "not_expired, #{hash_name} = false, options if not_expired && #{conds.join(' && ')}"
      end
    
      def add_segment(*segments)
        d = dup
        d.segments.concat segments
        yield d
      end
    
      def go
        if current then current.write_generation(self)
        else self.finish
        end
      end
    
      def continue
        d = dup
        d.before << d.current
        d.current = d.after.shift
        d.go
      end
    
      def finish
        line %("/#{segments.join('/')}")
      end

      def check_conditions(conditions)
        tests = []
        generator = nil
        conditions.each do |key, condition|
          tests << (generator || self).hash_value(key, true) if condition.is_a? Regexp
          tests << Routing.test_condition((generator || self).hash_value(key, false), condition)
          generator = self.dup unless generator
        end
        return tests.join(' && ')
      end
    end
  end
end
