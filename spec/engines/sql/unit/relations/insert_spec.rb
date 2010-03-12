require 'spec_helper'

module Arel
  describe Insert do
    before do
      @relation = Table.new(:users)
    end

    describe '#to_sql' do
      it 'manufactures sql inserting data when given multiple rows' do
        pending 'it should insert multiple rows' do
          @insertion = Insert.new(@relation, [@relation[:name] => "nick", @relation[:name] => "bryan"])

          @insertion.to_sql.should be_like("
            INSERT
            INTO `users`
            (`name`) VALUES ('nick'), ('bryan')
          ")
        end
      end

      it 'manufactures sql inserting data when given multiple values' do
        @insertion = Insert.new(@relation, @relation[:id] => "1", @relation[:name] => "nick")

        adapter_is :mysql do
          @insertion.to_sql.should be_like(%Q{
            INSERT
            INTO `users`
            (`id`, `name`) VALUES (1, 'nick')
          })
        end

        adapter_is :sqlite3 do
          @insertion.to_sql.should be_like(%Q{
            INSERT
            INTO "users"
            ("id", "name") VALUES (1, 'nick')
          })
        end

        adapter_is :postgresql do
          @insertion.to_sql.should be_like(%Q{
            INSERT
            INTO "users"
            ("id", "name") VALUES (1, E'nick')
            RETURNING "id"
          })
        end

        adapter_is :oracle do
          @insertion.to_sql.should be_like(%Q{
            INSERT
            INTO "USERS"
            ("ID", "NAME") VALUES (1, 'nick')
          })
        end
      end

      describe 'when given values whose types correspond to the types of the attributes' do
        before do
          @insertion = Insert.new(@relation, @relation[:name] => "nick")
        end

        it 'manufactures sql inserting data' do
          adapter_is :mysql do
            @insertion.to_sql.should be_like(%Q{
              INSERT
              INTO `users`
              (`name`) VALUES ('nick')
            })
          end

          adapter_is :sqlite3 do
            @insertion.to_sql.should be_like(%Q{
              INSERT
              INTO "users"
              ("name") VALUES ('nick')
            })
          end

          adapter_is :postgresql do
            @insertion.to_sql.should be_like(%Q{
              INSERT
              INTO "users"
              ("name") VALUES (E'nick')
              RETURNING "id"
            })
          end

          adapter_is :oracle do
            @insertion.to_sql.should be_like(%Q{
              INSERT
              INTO "USERS"
              ("NAME") VALUES ('nick')
            })
          end
        end
      end

      describe 'when given values whose types differ from from the types of the attributes' do
        before do
          @insertion = Insert.new(@relation, @relation[:id] => '1-asdf')
        end

        it 'manufactures sql inserting data' do
          adapter_is :mysql do
            @insertion.to_sql.should be_like(%Q{
              INSERT
              INTO `users`
              (`id`) VALUES (1)
            })
          end

          adapter_is :sqlite3 do
            @insertion.to_sql.should be_like(%Q{
              INSERT
              INTO "users"
              ("id") VALUES (1)
            })
          end

          adapter_is :postgresql do
            @insertion.to_sql.should be_like(%Q{
              INSERT
              INTO "users"
              ("id") VALUES (1)
              RETURNING "id"
            })
          end

          adapter_is :oracle do
            @insertion.to_sql.should be_like(%Q{
              INSERT
              INTO "USERS"
              ("ID") VALUES (1)
            })
          end

        end
      end
    end
  end
end
