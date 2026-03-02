# frozen_string_literal: true

ActiveRecord::ConnectionAdapters.register("abstract", "ActiveRecord::ConnectionAdapters::AbstractAdapter", "active_record/connection_adapters/abstract_adapter")
ActiveRecord::ConnectionAdapters.register("fake", "FakeActiveRecordAdapter", File.expand_path("../support/fake_adapter.rb", __dir__))
