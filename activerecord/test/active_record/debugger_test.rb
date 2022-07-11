# frozen_string_literal: true

require "cases/helper"
require "models/developer"
require "models/contract"
require "models/company"
require "models/computer"
require "models/mentor"
require "models/project"
require "models/ship"
require "models/ship_part"
require "models/strict_zine"
require "models/post"
require "models/pirate"
require "models/treasure"
require "models/book"

class DebuggerTest < ActiveRecord::TestCase
  fixtures :developers, :developers_projects, :projects, :ships, :books, :posts, :authors

  def setup
    ActiveRecord.load_tree_enabled = true
  end

  def teardown
    ActiveRecord.load_tree_enabled = false
  end

  def run_in_debug_mode(&block)
    ActiveRecord::Debugger.enable_debugging
    ActiveRecord::Debugger.clear_loaded_records
    yield
    ActiveRecord::Debugger.disable_debugging
    ActiveRecord::Debugger.clear_loaded_records
  end

  test "load tree must be enabled" do
    ActiveRecord.load_tree_enabled = false
    assert_raises(ActiveRecord::LoadTree::LoadTreeDisabledError) do
      ActiveRecord::Debugger.enable_debugging
    end
  end

  test "when in debug mode, maintain a class level list of root level objects loaded, all other objects are accessed via the load tree" do
     developer = Developer.first
     ship = Ship.first
     stern1 = ShipPart.create!(name: "Stern", ship: ship)
     trinket = stern1.trinkets.create!(name: "Stern Trinket")

     firm = Firm.create!(name: "NASA")
     project = Project.create!(name: "Apollo", firm: firm)

     ship.update_column(:developer_id, developer.id)
     developer.projects.destroy_all
     developer.projects << project
     run_in_debug_mode do
       child_records = [ship, stern1, trinket, project, firm]

       developer = Developer.find(developer.id)

       developer.projects.first.firm
       developer.ship.parts.first.trinkets.first
       assert ActiveRecord::Debugger.loaded_records.include?(developer)
       child_records.each do |record|
         assert_not ActiveRecord::Debugger.loaded_records.include?(record), "Expected #{record} to not be in the loaded records"
       end
     end
   end

  test "access a record with a find should add the record to loaded record" do
    ship = Ship.first
    run_in_debug_mode do
      ship = Ship.find(ship.id)

      assert ActiveRecord::Debugger.loaded_records.include?(ship)
    end
  end

  test "loading a record from array access should add the record to loaded records" do
    run_in_debug_mode do
      ship = Ship.first

      assert ActiveRecord::Debugger.loaded_records.include?(ship)
    end
  end

  test "accessing record from last" do
    Ship.first
    ship2 = Ship.create!(name: "Ship2")
    Ship.create!(name: "Ship3")

    run_in_debug_mode do
      Ship.second_to_last

      assert ActiveRecord::Debugger.loaded_records.include?(ship2)
      assert_equal 2, ActiveRecord::Debugger.loaded_records.size
    end
  end

  test "accesssing record with take" do
    Ship.create!(name: "Ship2")
    Ship.create!(name: "Ship3")

    run_in_debug_mode do
      ships = Ship.take(2)

      ships.each do |ship|
        assert ActiveRecord::Debugger.loaded_records.include?(ship)
        assert ActiveRecord::Debugger.loaded_records.include?(ship)
      end
    end
  end

  test "access last" do
    Ship.create!(name: "Ship2")

    run_in_debug_mode do
      ship = Ship.last

      assert ActiveRecord::Debugger.loaded_records.include?(ship)
    end
  end

  test "find_by" do
    ship = Ship.create!(name: "Ship2")
    run_in_debug_mode do
      Ship.find_by(name: "Ship2")

      assert ActiveRecord::Debugger.loaded_records.include?(ship)
    end
  end

  test "when in debug mode keep track of the call stack when a record is loaded" do
    developer = Developer.first
    ship = Ship.first
    ship.update_column(:developer_id, developer.id)
    ActiveRecord::Debugger.enable_debugging
    developer = Developer.find(developer.id)
    ship = developer.ship

    assert_not_nil ship._load_tree_node.load_call_stack
    assert_not_nil developer._load_tree_node.load_call_stack

    ActiveRecord::Debugger.disable_debugging
    developer = Developer.find(developer.id)
    ship = developer.ship

    assert_nil ship._load_tree_node.load_call_stack
    assert_nil developer._load_tree_node.load_call_stack
  end
end
