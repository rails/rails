class AlwaysSafe < ActiveRecord::Migration
  def change
    # do nothing to avoid side-effect conflicts from running multiple times
  end
end
