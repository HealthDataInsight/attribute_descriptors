require_relative '../metadata'

require 'rspec/core'
require 'test/unit' # Needed for assertion methods
require 'stringio'
require 'yaml'
require 'awesome_print'

#
# EXAMPLE 1
# NOTICE: \A..\z denote the start and end of the string. ^..$ should not be used
#         for security reasons.
#
metadata = '''
namelike:
  example: Seferidis
  invalid: Seferidis the 1st
  validate: \D*
  require: no
digits:
  example: 123456
  invalid: 12g334
  validate: \d{6}
  require: no
alphanumeric:
  example: abc44
  invalid: 12345
  validate: /[a-zA-Z]{3}\d{2}/
  require: no
gmail email:
  example: manossef@gmail.com
  invalid: manossef@yahoo.com
  validate: .*@gmail\.com
  require: no
'''
metafile = Tempfile.new('')
metafile.write(metadata)
metafile.close



describe 'attribute validations' do
  include Test::Unit::Assertions
  METADATA = Metadata.load_file(metafile.path)
  METADATA_PATH  = metafile.path


  class MyModel < Metadata::ModelGenerators
    use_metadata_at METADATA_PATH
    #@@metadata = Metadata.load_file(METADATA_PATH)
    generate_attributes_from_metadata
    generate_validations_from_metadata
  end

  # class MyModel
  #   Metadata::load_file METADATA_PATH
  #   Metadata::generate_attributes
  #   Metadata::generate_attributes
  # end

  it "very simple test 1" do
    m = MyModel.new({'namelike' => 'Seferidis'})
    assert m.valid?
  end
  #
  # it "very simple test 2" do
  #   m = MyModel.new({'namelike' => 'Seferidis the 1st'})
  #   assert ! m.valid?
  # end
  #
  # it "very simple test 3" do
  #   m = MyModel.new({'gmail_email' => 'manossef@gmail.com'})
  #   assert m.valid?
  # end
  #
  # it "very simple test 4" do
  #   m = MyModel.new({'gmail_email' => 'manossef@yahoo.com'})
  #   assert ! m.valid?
  # end
  #
  # it "very simple test 5" do
  #   m = MyModel.new({'alphanumeric' => '12345'})
  #   assert ! m.valid?
  # end
  #
  # # Run them all
  # METADATA.each do |fieldname, meta|
  #   describe "'#{fieldname}'" do
  #     it "should acknowledge '#{meta['example']}' as valid" do
  #       attrs = {meta['programmatic_name'] => meta['example']}
  #       assert MyModel.new(attrs).valid?
  #     end
  #     it "should acknowledge '#{meta['invalid']}' as invalid" do
  #       attrs = {meta['programmatic_name'] => meta['invalid']}
  #       assert ! MyModel.new(attrs).valid?
  #     end
  #   end
  # end


end
