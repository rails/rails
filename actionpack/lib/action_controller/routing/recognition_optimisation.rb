module ActionController
  module Routing
    # BEFORE:   0.191446860631307 ms/url
    # AFTER:    0.029847304022858 ms/url
    # Speed up: 6.4 times
    #
    # Route recognition is slow due to one-by-one iterating over
    # a whole routeset (each map.resources generates at least 14 routes)
    # and matching weird regexps on each step.
    #
    # We optimize this by skipping all URI segments that 100% sure can't
    # be matched, moving deeper in a tree of routes (where node == segment)
    # until first possible match is accured. In such case, we start walking
    # a flat list of routes, matching them with accurate matcher.
    # So, first step: search a segment tree for the first relevant index.
    # Second step: iterate routes starting with that index.
    #
    # How tree is walked? We can do a recursive tests, but it's smarter:
    # We just create a tree of if-s and elsif-s matching segments.
    #
    # We have segments of 3 flavors:
    # 1) nil (no segment, route finished)
    # 2) const-dot-dynamic (like "/posts.:xml", "/preview.:size.jpg")
    # 3) const (like "/posts", "/comments")
    # 4) dynamic ("/:id", "file.:size.:extension")
    #
    # We split incoming string into segments and iterate over them.
    # When segment is nil, we drop immediately, on a current node index.
    # When segment is equal to some const, we step into branch.
    # If none constants matched, we step into 'dynamic' branch (it's a last).
    # If we can't match anything, we drop to last index on a level.
    #
    # Note: we maintain the original routes order, so we finish building
    #       steps on a first dynamic segment.
    #
    #
    # Example. Given the routes:
    #   0 /posts/
    #   1 /posts/:id
    #   2 /posts/:id/comments
    #   3 /posts/blah
    #   4 /users/
    #   5 /users/:id
    #   6 /users/:id/profile
    #
    # request_uri = /users/123
    #
    # There will be only 4 iterations:
    #  1) segm test for /posts prefix, skip all /posts/* routes
    #  2) segm test for /users/
    #  3) segm test for /users/:id
    #     (jump to list index = 5)
    #  4) full test for /users/:id => here we are!
    class RouteSet
      def recognize_path(path, environment={})
        result = recognize_optimized(path, environment) and return result

        # Route was not recognized. Try to find out why (maybe wrong verb).
        allows = HTTP_METHODS.select { |verb| routes.find { |r| r.recognize(path, :method => verb) } }

        if environment[:method] && !HTTP_METHODS.include?(environment[:method])
          raise NotImplemented.new(*allows)
        elsif !allows.empty?
          raise MethodNotAllowed.new(*allows)
        else
          raise RoutingError, "No route matches #{path.inspect} with #{environment.inspect}"
        end
      end

      def segment_tree(routes)
        tree = [0]

        i = -1
        routes.each do |route|
          i += 1
          # not fast, but runs only once
          segments = to_plain_segments(route.segments.inject("") { |str,s| str << s.to_s })

          node  = tree
          segments.each do |seg|
            seg = :dynamic if seg && seg[0] == ?:
            node << [seg, [i]] if node.empty? || node[node.size - 1][0] != seg
            node = node[node.size - 1][1]
          end
        end
        tree
      end

      def generate_code(list, padding='  ', level = 0)
        # a digit
        return padding + "#{list[0]}\n" if list.size == 1 && !(Array === list[0])

        body = padding + "(seg = segments[#{level}]; \n"

        i = 0
        was_nil = false
        list.each do |item|
          if Array === item
            i += 1
            start = (i == 1)
            final = (i == list.size)
            tag, sub = item
            if tag == :dynamic
              body += padding + "#{start ? 'if' : 'elsif'} true\n"
              body += generate_code(sub, padding + "  ", level + 1)
              break
            elsif tag == nil && !was_nil
              was_nil = true
              body += padding + "#{start ? 'if' : 'elsif'} seg.nil?\n"
              body += generate_code(sub, padding + "  ", level + 1)
            else
              body += padding + "#{start ? 'if' : 'elsif'} seg == '#{tag}'\n"
              body += generate_code(sub, padding + "  ", level + 1)
            end
          end
        end
        body += padding + "else\n"
        body += padding + "  #{list[0]}\n"
        body += padding + "end)\n"
        body
      end

      # this must be really fast
      def to_plain_segments(str)
        str = str.dup
        str.sub!(/^\/+/,'')
        str.sub!(/\/+$/,'')
        segments = str.split(/\.[^\/]+\/+|\/+|\.[^\/]+\Z/) # cut off ".format" also
        segments << nil
        segments
      end

      private
        def write_recognize_optimized!
          tree = segment_tree(routes)
          body = generate_code(tree)

          remove_recognize_optimized!

          instance_eval %{
            def recognize_optimized(path, env)
              segments = to_plain_segments(path)
              index = #{body}
              return nil unless index
              while index < routes.size
                result = routes[index].recognize(path, env) and return result
                index += 1
              end
              nil
            end
          }, __FILE__, __LINE__
        end

        def clear_recognize_optimized!
          remove_recognize_optimized!

          class << self
            def recognize_optimized(path, environment)
              write_recognize_optimized!
              recognize_optimized(path, environment)
            end
          end
        end

        def remove_recognize_optimized!
          if respond_to?(:recognize_optimized)
            class << self
              remove_method :recognize_optimized
            end
          end
        end
    end
  end
end
