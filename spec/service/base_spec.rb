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
end
