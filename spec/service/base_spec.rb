require 'spec_helper'

describe Service::Base do
  class Service::Fake < Service::Base
    title 'Fake'
  end

  class Service::FakeWithExtraEvents < Service::Base
    handles :issue_velocity_alert, :issue_impact_change
  end

  describe '.services' do
    it 'tracks inheriting classes' do
      expect(Service.services['fake']).to eq(Service::Fake)
    end
  end

  describe '#display_error' do
    it 'escalates a user readable exception' do
      logger = double('fake-logger', :log => nil)
      service = Service::Fake.new({}, lambda { |message| logger.log(message)})

      expect {
        service.display_error('Oh no!')
      }.to raise_error(Service::DisplayableError, 'Oh no!')

      expect(logger).to have_received(:log).with('Oh no!')
    end
  end
end
