require_relative 'bootstrap'


class TestAttributeDescriptorsValidations < Test::Unit::TestCase

  # Simple descriptions
  METADATA = AttributeDescriptors::load_yaml('''
namelike:
  example: Seferidis
  invalid: Seferidis the 1st
  valid_values:
    - /\D*/
  require: no
digits_only:
  example: 123456
  invalid: 12g334
  valid_values:
    - /\d{6}/
  require: no
three_alpha_two_digits:
  example: abc44
  invalid: 12345
  valid_values:
    - /[a-zA-Z]{3}\d{2}/
  require: no
gmail email:
  example: manossef@gmail.com
  invalid: manossef@yahoo.com
  valid_values:
    - /.*@gmail\.com/
  require: no
''')


  class MyModel
    include AttributeDescriptors
    attr_descriptors METADATA
    generate_attr_accessors
    generate_validations

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

  # every single attribute
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


  # --------------------------- Simple validations -----------------------------

  test "required attributes cant be empty" do
    class MyModel2
      include AttributeDescriptors
      attr_descriptors({
          attr1: { 'require' => true }
      })
      generate_validations
    end
    m = MyModel2.new
    assert ! m.valid?
    m.attr1 = nil
    assert ! m.valid?
    m.attr1 = ''
    assert ! m.valid?
    m.attr1 = []
    assert ! m.valid?
    m.attr1 = {}
    assert ! m.valid?
    m.attr1 = 'yada yada'
    assert m.valid?
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
    include AttributeDescriptors
    attr_descriptors METADATA
    generate_validations

    def initialize(attrs = {})
      attrs.each do |attr_name, value|
        send("#{attr_name}=", value) if self.class.attributes.include? attr_name
      end
    end
  end

  test "invalidate an attribute if it's not inside the permitted window of values" do
    m = MyModel2.new({'fav_animals' => 'diplopodus'})
    assert !m.valid?
    m = MyModel2.new({'fav_animals' => 'hippo'})
    assert m.valid?
  end

  test "in case of a single item allowed it shouldnt make a difference if we "\
       "have a list with a single item" do
    m = MyModel2.new({'fav_animals' => 'hippo'})
    assert m.valid?
    m = MyModel2.new({'fav_animals' => ['hippo']})
    assert m.valid?
  end

  test "invalidate an attribute if not exact numbers of values are given" do
    m = MyModel2.new({'fav_animals' => ['hippo']})
    assert m.valid?
    m = MyModel2.new({'fav_animals' => ['hippo', 'snake']})
    assert !m.valid?
  end

  class MyModel3
    include AttributeDescriptors
    attr_descriptors({
      'attr1' => {
        'valid_num_values'  => '1'
      },
      'attr2' => {
        'valid_num_values' => '1+'
      },
      'attr3' => {
        'valid_num_values' => '0-3'
      },
      'attr4' => {
        'valid_num_values' => '2-4'
      }
    })
    generate_validations

    def initialize(attrs = {})
      attrs.each do |attr_name, value|
        send("#{attr_name}=", value) if self.class.metadata.include? attr_name
      end
    end
  end

  test "you should be able to specify an exact number of values to be given" do
    m = MyModel3.new({ 'attr1' => [1] })
    assert m.valid?
    m = MyModel3.new({ 'attr1' => [1, 2] })
    assert !m.valid?
    m = MyModel3.new({ 'attr1' => [] })
    assert !m.valid?
  end

  test "you should be able to specify a minimum of values to be given" do
    m = MyModel3.new({ 'attr2' => [] })
    assert !m.valid?
    m = MyModel3.new({ 'attr2' => [1] })
    assert m.valid?
    m = MyModel3.new({ 'attr2' => [1, 2] })
    assert m.valid?
    m = MyModel3.new({ 'attr2' => [1, 2, 3, 4, 5] })
    assert m.valid?
  end

  test "you should be able to specify a maximum of values to be given" do
    m = MyModel3.new({ 'attr3' => [] })
    assert m.valid?
    m = MyModel3.new({ 'attr3' => [1] })
    assert m.valid?
    m = MyModel3.new({ 'attr3' => [1, 2] })
    assert m.valid?
    m = MyModel3.new({ 'attr3' => [1, 2, 3, 4, 5] })
    assert !m.valid?
  end

  test "you should be able to specify a window of number of values" do
    m = MyModel3.new({ 'attr4' => [] })
    assert !m.valid?
    m = MyModel3.new({ 'attr4' => [1] })
    assert !m.valid?
    m = MyModel3.new({ 'attr4' => [1, 2] })
    assert m.valid?
    m = MyModel3.new({ 'attr4' => [1, 2, 3] })
    assert m.valid?
    m = MyModel3.new({ 'attr4' => [1, 2, 3, 4] })
    assert m.valid?
    m = MyModel3.new({ 'attr4' => [1, 2, 3, 4, 5] })
    assert !m.valid?
  end

end
