require_relative 'bootstrap'


class TestAttributeDescriptorsUsage < Test::Unit::TestCase

  # Create two classes with overlapping meta for our tests
  META1 = {
    'attr1': {
      'description' => 'class1 description for attr1'
    }
  }
  META2 = {
    'attr1' => {
      'description' => 'class2 description for attr1'
    },
    'attr2' => {
      'description' => 'class2 description for attr2'
    },
  }
  class MyModel1
    extend AttributeDescriptors::Attributes
    attr_metadata META1
  end
  class MyModel2
    extend AttributeDescriptors::Attributes
    attr_metadata META2
  end


  test "make sure we can access class' metadata directly" do
    assert MyModel1.metadata
    assert MyModel1.metadata == META1
  end

  test "make sure the classes' don't override each other's metadata in any way" do
    assert MyModel1.metadata == META1
    assert MyModel2.metadata == META2
  end

  test "make sure the class has Attribute instances generated" do
    assert MyModel1.attr1
    assert MyModel2.attr1
    assert MyModel2.attr2
    assert MyModel1.attr1.class == AttributeDescriptors::Attribute
    assert MyModel2.attr1.class == AttributeDescriptors::Attribute
    assert MyModel2.attr2.class == AttributeDescriptors::Attribute
  end


  test "you should be able to access the metadata directly with dot-notation" do
    assert MyModel1.attr1.description
    assert MyModel1.attr1.description == 'class1 description for attr1'
    assert MyModel2.attr1.description
    assert MyModel2.attr1.description == 'class2 description for attr1'
    assert MyModel2.attr2.description
    assert MyModel2.attr2.description == 'class2 description for attr2'
  end

  test "you should be able to access the view helpers" do
    assert MyModel1.attr1.as_input_field
  end

end
