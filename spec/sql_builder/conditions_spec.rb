require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe ConditionsBuilder do
  describe '#to_s' do
    describe 'with aliased columns' do
      it 'manufactures correct sql' do
        ConditionsBuilder.new do
          equals do
            column(:a, :b)
            column(:c, :d, 'e')
          end
        end.to_s.should be_like("""
          `a`.`b` = `c`.`d`
        """)
      end
    end
  end
end