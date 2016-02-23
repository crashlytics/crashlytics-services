require 'rspec/expectations'

class ServicePageMatcher
  attr_reader :service_class, :expected_page_name, :expected_options

  def initialize(service_class, expected_page_name, expected_options)
    @service_class = service_class
    @expected_page_name = expected_page_name
    @expected_options = expected_options
  end

  def matches?
    actual_page && matching_options?
  end

  def description
    "include page with name \"#{expected_page_name}\" for attributes: #{expected_options}"
  end

  def failure_message
    "".tap do |message|
      if actual_page
        message << "Found page with name \"#{expected_page_name}\""

        if matching_options?
          message << " with expected attributes #{expected_options}"
        else
          message << " with mismatching attributes #{actual_options} (expected #{expected_options})"
        end
      else
        message << "Did not find page with name \"#{expected_page_name}\""
      end
    end
  end

  private

  def actual_page
    @actual_page ||= @service_class.pages.detect { |page_configuration| page_configuration[:title] == @expected_page_name }
  end

  def actual_options
    actual_page ? actual_page[:attrs] : nil
  end

  def matching_options?
    RSpec::Matchers::BuiltIn::ContainExactly.new(expected_options).matches?(actual_options)
  end
end

# Defines a matcher for page specification:
#
#  describe 'display configuration' do
#    subject { Service::<SomeClass> }
#    it { is_expected.to include_page 'Credentials', [:username, :password] }
#  end
RSpec::Matchers.define :include_page do |page_name, expected_options|

  description do
    "include page \"#{page_name}\" with attributes #{expected_options}"
  end

  match do |service_class|
    ServicePageMatcher.new(service_class, page_name, expected_options).matches?
  end

  failure_message do |service_class|
    ServicePageMatcher.new(service_class, page_name, expected_options).failure_message
  end
end
