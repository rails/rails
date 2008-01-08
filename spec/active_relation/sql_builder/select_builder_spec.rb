require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe SelectBuilder do
  describe '#to_s' do
    describe 'with select and from clauses' do
      it 'manufactures correct sql' do
        SelectBuilder.new do
          select do
            all
          end
          from :users
        end.to_s.should be_like("""
          SELECT *
          FROM `users`
        """)
      end
    end
    
    describe 'with specified columns and column aliases' do
      it 'manufactures correct sql' do
        SelectBuilder.new do
          select do
            column :a, :b, 'c'
            column :e, :f
          end
          from :users
        end.to_s.should be_like("""
          SELECT `a`.`b` AS 'c', `e`.`f`
          FROM `users`
        """)
      end
    end
    
    describe 'with where clause' do
      it 'manufactures correct sql' do
        SelectBuilder.new do
          select do
            all
          end
          from :users
          where do
            equals do
              value 1
              column :b, :c
            end
          end
        end.to_s.should be_like("""
          SELECT *
          FROM `users`
          WHERE 1 = `b`.`c`
        """)        
      end
      
      it 'accepts arbitrary strings' do
        SelectBuilder.new do
          select do
            all
          end
          from :users
          where do
            value "'a' = 'a'"
          end
        end.to_s.should be_like("""
          SELECT *
          FROM `users`
          WHERE 'a' = 'a'
        """)        
      end
    end
    
    describe 'with inner join' do
      it 'manufactures correct sql' do
        SelectBuilder.new do
          select do
            all
          end
          from :users do
            inner_join(:friendships) do
              equals do
                column :users, :id
                column :friendships, :user_id
              end
            end
          end
        end.to_s.should be_like("""
          SELECT *
          FROM `users`
            INNER JOIN `friendships`
              ON `users`.`id` = `friendships`.`user_id`
        """)
      end

      it 'accepts arbitrary on strings' do
        SelectBuilder.new do
          select do
            all
          end
          from :users do
            inner_join :friendships do
              value "arbitrary"
            end
          end
        end.to_s.should be_like("""
          SELECT *
          FROM `users`
            INNER JOIN `friendships` ON arbitrary
        """)
      end
    end
    
    describe 'with order' do
      it 'manufactures correct sql' do
        SelectBuilder.new do
          select do
            all
          end
          from :users
          order_by do
            column :users, :id
            column :users, :created_at, 'alias'
          end
        end.to_s.should be_like("""
          SELECT *
          FROM `users`
          ORDER BY `users`.`id`, `users`.`created_at`
        """)
      end
    end
    
    describe 'with limit and/or offset' do
      it 'manufactures correct sql' do
        SelectBuilder.new do
          select do
            all
          end
          from :users
          limit 10
          offset 10
        end.to_s.should be_like("""
          SELECT *
          FROM `users`
          LIMIT 10
          OFFSET 10
        """)
      end
    end
  end
end