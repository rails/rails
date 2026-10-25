# frozen_string_literal: true

# :markup: markdown
ActiveRecord::ConnectionAdapters::AbstractAdapter.set_callback(:checkout, :after) do
  begin_transaction(joinable: false)
end
