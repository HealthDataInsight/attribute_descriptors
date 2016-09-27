require_relative 'bootstrap'


class TestAttributeDescriptorsAttribute < Test::Unit::TestCase

  class MyModel
    include AttributeDescriptors
    attr_descriptors({
      'digits' => {
        'valid_pattern'     => /\A\d*\z/,
        'description'       => 'description for digits',
        'programmatic_name' => 'digits',
        'placeholder'       => 'please give some digits',
        'require'           => true
      },
      'fivevalues' => {
        'valid_values'      => [
          5, 10, 15, 20, 25
        ],
        'description'       => 'very specific values',
        'programmatic_name' => 'fivevalues',
        'placeholder'       => 'please choose one value',
        'require'           => true
      },
    })
  end

  test "you should be able to access the view helpers" do
    assert MyModel.digits.as_input_field
    assert MyModel.fivevalues.as_input_field
  end

  test "text form input gives the right html" do
    assert MyModel.digits.as_input_field.include? "id='digits'"
    assert MyModel.digits.as_input_field.include? "name='digits'"
    assert MyModel.digits.as_input_field.include? "placeholder='please give some digits'"
    assert MyModel.digits.as_input_field.include? "type='text'"
  end

  test "multiple values form input gives the right html" do
    assert MyModel.fivevalues.as_input_field.include? "id='fivevalues'"
    assert MyModel.fivevalues.as_input_field.include? "name='fivevalues'"
    assert MyModel.fivevalues.as_input_field.include? "<select"
    assert MyModel.fivevalues.as_input_field.include? "<option"
    assert MyModel.fivevalues.as_input_field.include? ">please choose one value</option>"
    assert MyModel.fivevalues.as_input_field.include? ">5</option>"
    assert MyModel.fivevalues.as_input_field.include? ">10</option>"
    assert MyModel.fivevalues.as_input_field.include? ">15</option>"
    assert MyModel.fivevalues.as_input_field.include? ">20</option>"
    assert MyModel.fivevalues.as_input_field.include? ">25</option>"
    num_options = MyModel.fivevalues.as_input_field.split('</option>').size - 1
    assert num_options == 6
  end

  test "it should be possible to preselect or prefill a value" do
    assert MyModel.digits.as_input_field('123').include? "value='123'"
    assert MyModel.fivevalues.as_input_field(5).include? "selected>5</option>"
    options_selected = MyModel.fivevalues.as_input_field.split('selected>').size - 1
    assert options_selected == 0
    options_selected = MyModel.fivevalues.as_input_field(5).split('selected>').size - 1
    assert options_selected == 1
  end

  test "be careful of cross-scripting (injection of code to frontend)" do
    injection_segment = "''>Injected code<input class='"
    assert !MyModel.digits.as_input_field(injection_segment).include?(injection_segment)
  end
end
