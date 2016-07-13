require_relative 'bootstrap'


class TestAttributeDescriptorsUsage < Test::Unit::TestCase


  test "defining a class should not override the metadata of an other" do
    # A model based on METADATA1
    class MyModel1
      extend AttributeDescriptors::ClassAttributes
      attr_metadata({
        'attr1': {
          'description' => 'blahblah'
        }
      })
    end
    previous_model1_meta = MyModel1.metadata
    class MyModel2
      extend AttributeDescriptors::ClassAttributes
      attr_metadata({
        'attr1': {
          'description' => 'OVERRIDEN!'
        }
      })
    end
    assert previous_model1_meta == MyModel1.metadata
    assert MyModel2.metadata[:attr1]['description'] == 'OVERRIDEN!'
  end

end
