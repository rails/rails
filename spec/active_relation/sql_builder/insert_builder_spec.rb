require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe InsertBuilder do
  describe '#to_s' do
    it 'manufactures correct sql' do
      InsertBuilder.new do
        insert
        into :users
        columns do
          column :users, :id
          column :users, :name
        end
        values do
          row 1, 'bob'
          row 2, 'moe'
        end
      end.to_s.should be_like("""
        INSERT
        INTO `users`
        (`users`.`id`, `users`.`name`) VALUES (1, 'bob'), (2, 'moe')
      """)
    end
  end
end