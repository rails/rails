shared_examples_for "TreeManager" do
  describe "clone" do
    it "clones the insert statement" do
      subject.instance_variable_get("@head").should_receive(:clone).and_return(:foo) # TODO: ick.
      dolly = subject.clone
      dolly.instance_variable_get("@head").should == :foo
    end
  end
end
