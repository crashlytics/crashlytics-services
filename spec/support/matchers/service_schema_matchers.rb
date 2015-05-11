require 'rspec/expectations'

class ServiceSchemaMatcher
  attr_reader :service_class, :expected_name, :expected_type

  def initialize(service_class, expected_type, expected_name)
    @service_class = service_class
    @expected_type = expected_type
    @expected_name = expected_name
  end

  def matches?
    actual_field && matching_type?
  end

  def failure_message
    "".tap do |message|
      if actual_field
        message << "Found :#{expected_name}"

        if matching_type?
          message << " of expected type \"#{actual_type}\""
        else
          message << " of mismatching type \"#{actual_type}\" (expected \"#{expected_type}\")"
        end
      else
        message << "Did not find #{expected_type} field with name :#{expected_name}"
      end
    end
  end

  private

  def actual_field
    @actual_field ||= @service_class.schema.detect { |field_configuration| field_configuration[:name] == @expected_name }
  end

  def actual_type
    actual_field ? actual_field[:type] : nil
  end

  def matching_type?
    actual_type == expected_type
  end
end

# Defines a matcher for each possible schema field type, to be used as follows:
#
#  describe 'schema configuration' do
#    subject { Service::<SomeClass> }
#    it { is_expected.to include_string_field :username }
#    it { is_expected.to include_password_field :password }
#    it { is_expected.to include_checkbox_field :enable_ssl }
#  end
[:checkbox, :password, :string].each do |field_type|
  RSpec::Matchers.define "include_#{field_type}_field" do |field_name|

    description do
      "include #{field_type} :#{field_name}"
    end

    match do |service_class|
      ServiceSchemaMatcher.new(service_class, field_type, field_name).matches?
    end

    failure_message do |service_class|
      ServiceSchemaMatcher.new(service_class, field_type, field_name).failure_message
    end
  end
end
