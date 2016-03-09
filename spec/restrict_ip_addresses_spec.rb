require 'spec_helper'
require 'restrict_ip_addresses'

describe Faraday::RestrictIPAddressesMiddleware do
  let(:host) { 'host' }
  let(:app) { double() }
  let(:env) do
    {
      :url => double()
    }
  end
  let(:middleware) { Faraday::RestrictIPAddressesMiddleware.new(app) }

  before do
    allow(env[:url]).to receive(:host).and_return(host)
    allow(middleware).to receive(:addresses).with(host).and_return(ip_addresses)
  end

  context 'blacklisted ip' do
    let(:ip_addresses) do
      [
        IPAddr.new('173.255.210.166'),
        IPAddr.new('169.254.169.254'), # blacklisted
      ]
    end

    it 'rejects the request' do
      expect(app).to_not receive(:call)
      expect {
        middleware.call(env)
      }.to raise_error(Faraday::AddressNotAllowed)
    end
  end

  context 'no blacklisted ips' do
    let(:ip_addresses) do
      [
        IPAddr.new('173.255.210.166'),
        IPAddr.new('173.255.210.176'),
      ]
    end

    it 'accepts the request' do
      expect(app).to receive(:call)
      middleware.call(env)
    end
  end
end
