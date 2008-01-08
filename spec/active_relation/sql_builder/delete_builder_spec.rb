require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe DeleteBuilder do
  describe '#to_s' do
    it 'manufactures correct sql' do
      DeleteBuilder.new do
        delete
        from :users
        where do
          equals do
            column :users, :id
            value 1
          end
        end
      end.to_s.should be_like("""
        DELETE
        FROM `users`
        WHERE `users`.`id` = 1
      """)
    end
  end
end