require 'faraday/middleware'
require 'faraday/error'
require 'ipaddr'
require 'uri'

# Heavily influenced by https://github.com/bhuga/faraday-restrict-ip-addresses

BLACKLISTED_IP_RANGES = [
  '::1',
  '::/128',
  '::1/128',
  'fe80::10',
  'fc00::/7',
  '127.0.0.0/8',
  '10.0.0.0/8',
  '172.16.0.0/12',
  '192.168.0.0/16',
  '0.0.0.0/8',          #  "This" Network [RFC1700, page 4]
  '100.64.0.0/10',      #  Shared address space [6598, 6890]
  '169.254.0.0/16',     #  Link Local [3927, 6890]
  '192.0.0.0/24',       #  Reserved but subject to allocation [6890]
  '192.0.0.0/29',       #  DS-Lite                        [6333, 6890]. Redundant with above, included for completeness.
  '192.0.2.0/24',       #  Documentation                  [5737, 6890]
  '192.88.99.0/24',     #  6to4 Relay Anycast             [3068, 6890]
  '198.18.0.0/15',      #  Network Interconnect Device Benchmark Testing [2544, 6890]
  '198.51.100.0/24',    #  Documentation                  [5737, 6890]
  '203.0.113.0/24',     #  Documentation                  [5737, 6890]
  '224.0.0.0/4',        #  Multicast                      [11112]
  '240.0.0.0/4',        #  Reserved for Future Use        [6890]
  '255.255.255.255/32', #  Reserved for Future Use        [6890]
].map { |net| IPAddr.new(net) }

module Faraday
  class AddressNotAllowed < Faraday::Error::ClientError ; end
  class RestrictIPAddressesMiddleware < Faraday::Middleware
    def initialize(app, options = {})
      super(app)
    end

    def call(env)
      raise AddressNotAllowed.new('Invalid Address') if denied?(env)
      @app.call(env)
    end

    def denied?(env)
      addresses(env[:url].host).any? { |a| denied_ip?(a) }
    end

    private

    def addresses(hostname)
      Socket.gethostbyname(hostname).map { |a| IPAddr.new_ntoh(a) rescue nil }.compact
    end

    def denied_ip?(ipaddr)
      BLACKLISTED_IP_RANGES.any? { |blacklisted_range| blacklisted_range.include?(ipaddr) }
    end
  end
end
