# frozen_string_literal: true

module ActionDispatch
  # :stopdoc:
  module Journey
    class Route
      attr_reader :app, :path, :defaults, :name, :precedence

      attr_reader :constraints, :internal
      alias :conditions :constraints

      module VerbMatchers
        VERBS = %w{ DELETE GET HEAD OPTIONS LINK PATCH POST PUT TRACE UNLINK }
        VERBS.each do |v|
          class_eval <<-eoc, __FILE__, __LINE__ + 1
            class #{v}
              def self.verb; name.split("::").last; end
              def self.call(req); req.#{v.downcase}?; end
            end
          eoc
        end

        class Unknown
          attr_reader :verb

          def initialize(verb)
            @verb = verb
          end

          def call(request); @verb === request.request_method; end
        end

        class All
          def self.call(_); true; end
          def self.verb; ""; end
        end

        VERB_TO_CLASS = VERBS.each_with_object(all: All) do |verb, hash|
          klass = const_get verb
          hash[verb]                 = klass
          hash[verb.downcase]        = klass
          hash[verb.downcase.to_sym] = klass
        end
      end

      def self.verb_matcher(verb)
        VerbMatchers::VERB_TO_CLASS.fetch(verb) do
          VerbMatchers::Unknown.new verb.to_s.dasherize.upcase
        end
      end

      def self.build(name, app, path, constraints, required_defaults, defaults)
        request_method_match = verb_matcher(constraints.delete(:request_method))
        new name, app, path, constraints, required_defaults, defaults, request_method_match, 0
      end

      ##
      # +path+ is a path constraint.
      # +constraints+ is a hash of constraints to be applied to this route.
      def initialize(name, app, path, constraints, required_defaults, defaults, request_method_match, precedence, internal = false)
        @name        = name
        @app         = app
        @path        = path

        @request_method_match = request_method_match
        @constraints = constraints
        @defaults    = defaults
        @required_defaults = nil
        @_required_defaults = required_defaults
        @required_parts    = nil
        @parts             = nil
        @decorated_ast     = nil
        @precedence        = precedence
        @path_formatter    = @path.build_formatter
        @internal          = internal
      end

      def eager_load!
        path.eager_load!
        ast
        parts
        required_defaults
        nil
      end

      def ast
        @decorated_ast ||= begin
          decorated_ast = path.ast
          decorated_ast.find_all(&:terminal?).each { |n| n.memo = self }
          decorated_ast
        end
      end

      # Needed for `rails routes`. Picks up succinctly defined requirements
      # for a route, for example route
      #
      #   get 'photo/:id', :controller => 'photos', :action => 'show',
      #     :id => /[A-Z]\d{5}/
      #
      # will have {:controller=>"photos", :action=>"show", :id=>/[A-Z]\d{5}/}
      # as requirements.
      def requirements
        @defaults.merge(path.requirements).delete_if { |_, v|
          /.+?/ == v
        }
      end

      def segments
        path.names
      end

      def required_keys
        required_parts + required_defaults.keys
      end

      def score(supplied_keys)
        required_keys = path.required_names

        required_keys.each do |k|
          return -1 unless supplied_keys.include?(k)
        end

        score = 0
        path.names.each do |k|
          score += 1 if supplied_keys.include?(k)
        end

        score + (required_defaults.length * 2)
      end

      def parts
        @parts ||= segments.map(&:to_sym)
      end
      alias :segment_keys :parts

      def format(path_options)
        @path_formatter.evaluate path_options
      end

      def required_parts
        @required_parts ||= path.required_names.map(&:to_sym)
      end

      def groupped_parts
        @groupped_parts ||= path.groupped_names.map do |group|
          group.map(&:to_sym)
        end
      end

      def required_default?(key)
        @_required_defaults.include?(key)
      end

      def required_defaults
        @required_defaults ||= @defaults.dup.delete_if do |k, _|
          parts.include?(k) || !required_default?(k)
        end
      end

      def glob?
        !path.spec.grep(Nodes::Star).empty?
      end

      def dispatcher?
        @app.dispatcher?
      end

      def matches?(request)
        match_verb(request) &&
        constraints.all? { |method, value|
          case value
          when Regexp, String
            value === request.send(method).to_s
          when Array
            value.include?(request.send(method))
          when TrueClass
            request.send(method).present?
          when FalseClass
            request.send(method).blank?
          else
            value === request.send(method)
          end
        }
      end

      def ip
        constraints[:ip] || //
      end

      def requires_matching_verb?
        !@request_method_match.all? { |x| x == VerbMatchers::All }
      end

      def verb
        verbs.join("|")
      end

      private
        def verbs
          @request_method_match.map(&:verb)
        end

        def match_verb(request)
          @request_method_match.any? { |m| m.call request }
        end
    end
  end
  # :startdoc:
end
