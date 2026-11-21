# frozen_string_literal: true

require "cases/helper"
require "active_support/core_ext/object/with"
require "timeout"
require "models/tree"
require "models/node"

class TouchLaterOrderingTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  include WaitForTestHelper

  fixtures :trees, :nodes

  class Tree < ActiveRecord::Base
    self.table_name = "trees"

    before_commit { Thread.current[:touch_later_callbacks]&.push(id) }
    after_commit { Thread.current[:touch_later_after_commit]&.push(id) }

    after_touch do
      Thread.current[:touch_later_order]&.push([self.class.table_name, id])
      if gate = Thread.current[:touch_later_gate]
        Thread.current[:touch_later_gate] = nil
        gate.first << true
        gate.last.pop
      end
    end
  end

  class Node < ActiveRecord::Base
    self.table_name = "nodes"

    belongs_to :tree, class_name: Tree.name, touch: true
    belongs_to :parent, class_name: name, touch: true, optional: true

    after_touch { Thread.current[:touch_later_order]&.push([self.class.table_name, id]) }
  end

  class Invoice < ActiveRecord::Base
    self.table_name = "invoices"

    after_touch { Thread.current[:touch_later_order]&.push([self.class.table_name, id]) }
  end

  class MiddleNode < ActiveRecord::Base
    self.table_name = "nodes"

    belongs_to :invoice, class_name: Invoice.name, foreign_key: :tree_id, touch: true

    after_touch { Thread.current[:touch_later_order]&.push([self.class.table_name, id]) }
  end

  class DeepTree < Tree
    belongs_to :node, class_name: MiddleNode.name, foreign_key: :name, touch: true, optional: true
  end

  class PolymorphicTree < Tree
    attribute :touchable_type, :string, default: Invoice.name
    belongs_to :touchable, polymorphic: true, foreign_key: :name, touch: true, optional: true
  end

  class BareNode < ActiveRecord::Base
    self.table_name = "nodes"

    after_touch { Thread.current[:touch_later_order]&.push([self.class.table_name, id]) }
  end

  class HasOneTree < Tree
    has_one :node, class_name: BareNode.name, foreign_key: :tree_id, touch: true
  end

  class CycleTree < Tree
    belongs_to :node, class_name: "TouchLaterOrderingTest::CycleNode", foreign_key: :name, touch: true, optional: true
  end

  class CycleNode < ActiveRecord::Base
    self.table_name = "nodes"

    belongs_to :tree, class_name: CycleTree.name, touch: true

    after_touch { Thread.current[:touch_later_order]&.push([self.class.table_name, id]) }
  end

  teardown do
    Thread.current[:touch_later_order] = nil
    Thread.current[:touch_later_callbacks] = nil
    Thread.current[:touch_later_after_commit] = nil
  end

  [true, false].each do |all_records|
    test "deferred touches use primary key order with all records #{all_records}" do
      with_all_records(all_records) do
        second = Tree.create!
        first = Tree.find(trees(:root).id)
        Thread.current[:touch_later_order] = []
        Thread.current[:touch_later_after_commit] = []

        assert_no_queries_match(/SELECT/i) do
          Tree.transaction do
            second.touch_later
            first.touch_later
          end
        end

        assert_equal [["trees", first.id], ["trees", second.id]], Thread.current[:touch_later_order]
        assert_equal [second.id, first.id], Thread.current[:touch_later_after_commit]
      end
    end

    test "chained touches run descendants before ancestors with all records #{all_records}" do
      with_all_records(all_records) do
        parent = Node.find(nodes(:parent_a).id)
        Thread.current[:touch_later_order] = []

        Node.transaction { parent.touch_later }

        assert_equal [
          ["nodes", parent.id],
          ["nodes", nodes(:grandparent).id],
          ["trees", trees(:root).id],
        ], Thread.current[:touch_later_order]
        assert_equal parent.parent.updated_at, Node.find(parent.parent.id).updated_at
      end
    end

    test "touch depth takes precedence over table names with all records #{all_records}" do
      with_all_records(all_records) do
        invoice = Invoice.create!
        node = MiddleNode.create!(tree_id: invoice.id)
        tree = DeepTree.create!(name: node.id.to_s)
        Thread.current[:touch_later_order] = []

        Tree.transaction do
          invoice.touch_later
          node.touch_later
          tree.touch_later
        end

        assert_equal ["trees", "nodes", "invoices"], Thread.current[:touch_later_order].map(&:first)
      end
    end

    test "polymorphic touches are ordered with all records #{all_records}" do
      with_all_records(all_records) do
        invoice = Invoice.create!
        tree = PolymorphicTree.create!(name: invoice.id.to_s)
        Thread.current[:touch_later_order] = []

        Tree.transaction do
          invoice.touch_later
          tree.touch_later
        end

        assert_equal ["trees", "invoices"], Thread.current[:touch_later_order].map(&:first)
      end
    end

    test "polymorphic touches retain multiple levels with all records #{all_records}" do
      with_all_records(all_records) do
        invoice = Invoice.create!
        node = MiddleNode.create!(tree_id: invoice.id)
        tree = PolymorphicTree.create!(name: node.id.to_s, touchable_type: MiddleNode.name)
        Thread.current[:touch_later_order] = []

        Tree.transaction do
          invoice.touch_later
          node.touch_later
          tree.touch_later
        end

        assert_equal ["trees", "nodes", "invoices"], Thread.current[:touch_later_order].map(&:first)
      end
    end

    test "has one touches remain immediate with all records #{all_records}" do
      with_all_records(all_records) do
        tree = HasOneTree.create!
        BareNode.create!(tree_id: tree.id)
        Thread.current[:touch_later_order] = []

        Tree.transaction do
          tree.touch_later
          assert_equal ["nodes"], Thread.current[:touch_later_order].map(&:first)
        end

        assert_equal ["nodes", "trees", "nodes"], Thread.current[:touch_later_order].map(&:first)
      end
    end

    test "cyclic association definitions terminate with all records #{all_records}" do
      with_all_records(all_records) do
        tree = CycleTree.create!
        node = CycleNode.create!(tree: tree)
        Thread.current[:touch_later_order] = []

        Node.transaction { node.touch_later }

        assert_equal ["nodes", "trees"], Thread.current[:touch_later_order].map(&:first)
      end
    end

    test "unrelated tables use a consistent order with all records #{all_records}" do
      with_all_records(all_records) do
        tree = Tree.find(trees(:root).id)
        invoice = Invoice.create!
        Thread.current[:touch_later_order] = []

        Tree.transaction do
          tree.touch_later
          invoice.touch_later
        end

        assert_equal ["invoices", "trees"], Thread.current[:touch_later_order].map(&:first)
      end
    end

    test "ordinary callback positions are preserved among touches with all records #{all_records}" do
      with_all_records(all_records) do
        first = Tree.find(trees(:root).id)
        middle = Tree.create!
        last = Tree.create!
        Thread.current[:touch_later_callbacks] = []

        Tree.transaction do
          last.touch_later
          middle.update!(name: "middle")
          first.touch_later
        end

        assert_equal [first.id, middle.id, last.id], Thread.current[:touch_later_callbacks]
      end
    end

    test "ordinary before commit callbacks retain their order with all records #{all_records}" do
      with_all_records(all_records) do
        first = Tree.find(trees(:root).id)
        second = Tree.create!
        Thread.current[:touch_later_callbacks] = []

        Tree.transaction do
          second.update!(name: "second")
          first.update!(name: "first")
        end

        assert_equal [second.id, first.id], Thread.current[:touch_later_callbacks]
      end
    end

    test "opposite touch orders do not deadlock with all records #{all_records}" do
      skip "PostgreSQL lock observation is required" unless current_adapter?(:PostgreSQLAdapter)

      with_all_records(all_records) do
        first = trees(:root).id
        second = Tree.create!.id
        touched = Queue.new
        release = Queue.new
        backend = Queue.new
        threads = []

        begin
          threads << touch_in_thread([first, second], gate: [touched, release])
          Timeout.timeout(10) { touched.pop }
          threads << touch_in_thread([second, first], backend: backend)
          pid = Timeout.timeout(10) { backend.pop }

          # On the old implementation B locks the second row, then waits for A.
          # With ordered touches B waits on A's first row instead. Once B is
          # waiting, let A proceed: only the former schedule forms a cycle.
          wait_for(timeout: 10) do
            Tree.lease_connection.select_value(<<~SQL)
              SELECT wait_event_type = 'Lock' FROM pg_stat_activity WHERE pid = #{Integer(pid)}
            SQL
          end
          release << true
          results = Timeout.timeout(15) { threads.map(&:value) }

          assert_equal [nil, nil], results, results.compact.map(&:full_message).join("\n")
        ensure
          release << true
          threads.each do |thread|
            thread.join(2) || thread.kill.join
          end
        end
      end
    end
  end

  private
    def with_all_records(value, &block)
      ActiveRecord.with(before_committed_on_all_records: value, &block)
    end

    def touch_in_thread(ids, gate: nil, backend: nil)
      Thread.new do
        Thread.current.abort_on_exception = false
        Thread.current.report_on_exception = false
        Tree.connection_pool.with_connection do |connection|
          backend << connection.select_value("SELECT pg_backend_pid()") if backend
          Thread.current[:touch_later_gate] = gate
          Tree.transaction { ids.each { |id| Tree.find(id).touch_later } }
        end
        nil
      rescue StandardError => error
        error
      end
    end
end
