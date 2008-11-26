module ActionController
  module Routing
    # Much of the slow performance from routes comes from the
    # complexity of expiry, <tt>:requirements</tt> matching, defaults providing
    # and figuring out which url pattern to use.  With named routes
    # we can avoid the expense of finding the right route.  So if
    # they've provided the right number of arguments, and have no
    # <tt>:requirements</tt>, we can just build up a string and return it.
    #
    # To support building optimisations for other common cases, the
    # generation code is separated into several classes
    module Optimisation
      def generate_optimisation_block(route, kind)
        return "" unless route.optimise?
        OPTIMISERS.inject("") do |memo, klazz|
          memo << klazz.new(route, kind).source_code
          memo
        end
      end

      class Optimiser
        attr_reader :route, :kind
        GLOBAL_GUARD_CONDITIONS = [
          "(!defined?(default_url_options) || default_url_options.blank?)",
          "(!defined?(controller.default_url_options) || controller.default_url_options.blank?)",
          "defined?(request)",
          "request"
          ]

        def initialize(route, kind)
          @route = route
          @kind  = kind
        end

        def guard_conditions
          ["false"]
        end

        def generation_code
          'nil'
        end

        def source_code
          if applicable?
            guard_condition = (GLOBAL_GUARD_CONDITIONS + guard_conditions).join(" && ")
            "return #{generation_code} if #{guard_condition}\n"
          else
            "\n"
          end
        end

        # Temporarily disabled <tt>:url</tt> optimisation pending proper solution to
        # Issues around request.host etc.
        def applicable?
          true
        end
      end

      # Given a route
      #
      #   map.person '/people/:id'
      #
      # If the user calls <tt>person_url(@person)</tt>, we can simply
      # return a string like "/people/#{@person.to_param}"
      # rather than triggering the expensive logic in +url_for+.
      class PositionalArguments < Optimiser
        def guard_conditions
          number_of_arguments = route.required_segment_keys.size
          # if they're using foo_url(:id=>2) it's one
          # argument, but we don't want to generate /foos/id2
          if number_of_arguments == 1
            ["args.size == 1", "!args.first.is_a?(Hash)"]
          else
            ["args.size == #{number_of_arguments}"]
          end
        end

        def generation_code
          elements = []
          idx = 0

          if kind == :url
            elements << '#{request.protocol}'
            elements << '#{request.host_with_port}'
          end

          elements << '#{ActionController::Base.relative_url_root if ActionController::Base.relative_url_root}'

          # The last entry in <tt>route.segments</tt> appears to *always* be a
          # 'divider segment' for '/' but we have assertions to ensure that
          # we don't include the trailing slashes, so skip them.
          (route.segments.size == 1 ? route.segments : route.segments[0..-2]).each do |segment|
            if segment.is_a?(DynamicSegment)
              elements << segment.interpolation_chunk("args[#{idx}].to_param")
              idx += 1
            else
              elements << segment.interpolation_chunk
            end
          end
          %("#{elements * ''}")
        end
      end

      # This case is mostly the same as the positional arguments case
      # above, but it supports additional query parameters as the last
      # argument
      class PositionalArgumentsWithAdditionalParams < PositionalArguments
        def guard_conditions
          ["args.size == #{route.segment_keys.size + 1}"] +
          UrlRewriter::RESERVED_OPTIONS.collect{ |key| "!args.last.has_key?(:#{key})" }
        end

        # This case uses almost the same code as positional arguments,
        # but add a question mark and args.last.to_query on the end,
        # unless the last arg is empty
        def generation_code
          super.insert(-2, '#{\'?\' + args.last.to_query unless args.last.empty?}')
        end

        # To avoid generating "http://localhost/?host=foo.example.com" we
        # can't use this optimisation on routes without any segments
        def applicable?
          super && route.segment_keys.size > 0
        end
      end

      OPTIMISERS = [PositionalArguments, PositionalArgumentsWithAdditionalParams]
    end
  end
end
