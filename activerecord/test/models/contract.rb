# frozen_string_literal: true

class Contract < ActiveRecord::Base
  belongs_to :company
  belongs_to :developer, primary_key: :id
  belongs_to :firm, foreign_key: "company_id"

  attribute :metadata, :json

  before_save :hi, :update_metadata
  after_save :bye

  attr_accessor :hi_count, :bye_count

  def hi
    @hi_count ||= 0
    @hi_count += 1
  end

  def bye
    @bye_count ||= 0
    @bye_count += 1
  end

  def update_metadata
    # 'code' makes the JSON string consistently orderable, which is used
    # by RelationsTest "joins with order by custom attribute". Without
    # this it would still pass 99% of the time, but fail when two
    # records' company_id lexical and numeric order differ (99, 100).
    self.metadata = { code: company_id && "%08x" % company_id, company_id: company_id, developer_id: developer_id }
  end
end

class NewContract < Contract
  validates :company_id, presence: true
end

class SpecialContract < ActiveRecord::Base
  self.table_name = "contracts"
  belongs_to :company
  belongs_to :special_developer, foreign_key: "developer_id"
end
