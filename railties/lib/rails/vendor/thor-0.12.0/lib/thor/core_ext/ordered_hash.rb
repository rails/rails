class Thor
  module CoreExt #:nodoc:

    if RUBY_VERSION >= '1.9'
      class OrderedHash < ::Hash
      end
    else
      # This class is based on the Ruby 1.9 ordered hashes.
      #
      # It keeps the semantics and most of the efficiency of normal hashes
      # while also keeping track of the order in which elements were set.
      #
      class OrderedHash #:nodoc:
        include Enumerable

        Node = Struct.new(:key, :value, :next, :prev)

        def initialize
          @hash = {}
        end

        def [](key)
          @hash[key] && @hash[key].value
        end

        def []=(key, value)
          if node = @hash[key]
            node.value = value
          else
            node = Node.new(key, value)

            if @first.nil?
              @first = @last = node
            else
              node.prev = @last
              @last.next = node
              @last = node
            end
          end

          @hash[key] = node
          value
        end

        def delete(key)
          if node = @hash[key]
            prev_node = node.prev
            next_node = node.next

            next_node.prev = prev_node if next_node
            prev_node.next = next_node if prev_node

            @first = next_node if @first == node
            @last = prev_node  if @last  == node

            value = node.value
          end

          @hash.delete(key)
          value
        end

        def keys
          self.map { |k, v| k }
        end

        def values
          self.map { |k, v| v }
        end

        def each
          return unless @first
          yield [@first.key, @first.value]
          node = @first
          yield [node.key, node.value] while node = node.next
          self
        end

        def merge(other)
          hash = self.class.new

          self.each do |key, value|
            hash[key] = value
          end

          other.each do |key, value|
            hash[key] = value
          end

          hash
        end

        def empty?
          @hash.empty?
        end
      end
    end

  end
end
