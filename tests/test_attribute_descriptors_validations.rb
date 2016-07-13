require_relative 'bootstrap'


class TestAttributeDescriptorsValidations < Test::Unit::TestCase

  # Simple descriptions
  METADATA = AttributeDescriptors::load_yaml('''
namelike:
  example: Seferidis
  invalid: Seferidis the 1st
  validate: \D*
  require: no
digits_only:
  example: 123456
  invalid: 12g334
  validate: \d{6}
  require: no
three_alpha_two_digits:
  example: abc44
  invalid: 12345
  validate: /[a-zA-Z]{3}\d{2}/
  require: no
gmail email:
  example: manossef@gmail.com
  invalid: manossef@yahoo.com
  validate: .*@gmail\.com
  require: no
''')


  class MyModel
    extend AttributeDescriptors::ClassAttributes
    attr_metadata_meta METADATA

    def initialize(attrs = {})
      attrs.each do |attr_name, value|
        send("#{attr_name}=", value) if self.class.attributes.include? attr_name
      end
    end
  end

  test "very simple test 1" do
    m = MyModel.new({'namelike' => 'Seferidis'})
    assert m.valid?
  end

  test "very simple test 2" do
    m = MyModel.new({'namelike' => 'Seferidis the 1st'})
    assert ! m.valid?
  end

  test "very simple test 3" do
    m = MyModel.new({'gmail_email' => 'manossef@gmail.com'})
    assert m.valid?
  end

  test "very simple test 4" do
    m = MyModel.new({'gmail_email' => 'manossef@yahoo.com'})
    assert ! m.valid?
  end

  test "very simple test 5" do
    m = MyModel.new({'three_alpha_two_digits' => '12345'})
    assert ! m.valid?
  end

  test "every single attribute"
  METADATA.each do |fieldname, meta|
    test "#{fieldname} should acknowledge '#{meta['example']}' as valid" do
      attrs = {meta['programmatic_name'] => meta['example']}
      assert MyModel.new(attrs).valid?
    end
    test "#{fieldname} should acknowledge '#{meta['invalid']}' as invalid" do
      attrs = {meta['programmatic_name'] => meta['invalid']}
      assert ! MyModel.new(attrs).valid?
    end
  end



  # -------------------------- Advanced validations ----------------------------


  # Descriptions with multiple values
  METADATA = AttributeDescriptors::load_yaml('''
Favorite animals:
  programmatic_name: fav_animals
  valid_num_values: 1
  valid_values:
    - snake
    - hippo
    - squirel
    - other
''')

  class MyModel2
    extend AttributeDescriptors::ClassAttributes
    attr_metadata_meta METADATA

    def initialize(attrs = {})
      attrs.each do |attr_name, value|
        send("#{attr_name}=", value) if self.class.attributes.include? attr_name
      end
    end
  end

  # test "limits valid values based on metadata" do
  #   m = MyModel.new({'fav_animals' => 'e'})
  #   assert m.valid?
  #   m = MyModel.new({'fav_animals' => 'g'})
  #   assert !m.valid?
  # end

  # test "invalidate an attribute if not exact numbers of values are given" do
  #   m = MyModel.new({'fav_animals' => ['a']})
  #   assert !m.valid?
  #   m = MyModel.new({'fav_animals' => ['a', 'e']})
  #   assert m.valid?
  #   m = MyModel.new({'fav_animals' => ['a', 'e', 'i']})
  #   assert !m.valid?
  # end

  # CURRENTLY ONLY WORKING WITH NON-ARRAY
  test "invalidate an attribute if it's not inside the permitted window of values" do
    m = MyModel2.new({'fav_animals' => 'cat'})
    assert !m.valid?
    m = MyModel2.new({'fav_animals' => 'hippo'})
    assert m.valid?
  end


end
