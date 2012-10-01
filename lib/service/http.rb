module Service
  module HTTP
    # Public: Makes an HTTP GET call.
    #
    # url     - Optional String URL to request.
    # params  - Optional Hash of GET parameters to set.
    # headers - Optional Hash of HTTP headers to set.
    #
    # Examples
    #
    #   http_get("http://github.com")
    #   # => <Faraday::Response>
    #
    #   # GET http://github.com?page=1
    #   http_get("http://github.com", :page => 1)
    #   # => <Faraday::Response>
    #
    #   http_get("http://github.com", {:page => 1},
    #     'Accept': 'application/json')
    #   # => <Faraday::Response>
    #
    #   # Yield the Faraday::Response for more control.
    #   http_get "http://github.com" do |req|
    #     req.basic_auth("username", "password")
    #     req.params[:page] = 1
    #     req.headers['Accept'] = 'application/json'
    #   end
    #   # => <Faraday::Response>
    #
    # Yields a Faraday::Request instance.
    # Returns a Faraday::Response instance.
    def http_get(url = nil, params = nil, headers = nil)
      http.get do |req|
        req.url(url)                if url
        req.params.update(params)   if params
        req.headers.update(headers) if headers
        yield req if block_given?
      end
    end

    # Public: Makes an HTTP POST call.
    #
    # url     - Optional String URL to request.
    # body    - Optional String Body of the POST request.
    # headers - Optional Hash of HTTP headers to set.
    #
    # Examples
    #
    #   http_post("http://github.com/create", "foobar")
    #   # => <Faraday::Response>
    #
    #   http_post("http://github.com/create", "foobar",
    #     'Accept': 'application/json')
    #   # => <Faraday::Response>
    #
    #   # Yield the Faraday::Response for more control.
    #   http_post "http://github.com/create" do |req|
    #     req.basic_auth("username", "password")
    #     req.params[:page] = 1 # http://github.com/create?page=1
    #     req.headers['Content-Type'] = 'application/json'
    #     req.body = {:foo => :bar}.to_json
    #   end
    #   # => <Faraday::Response>
    #
    # Yields a Faraday::Request instance.
    # Returns a Faraday::Response instance.
    def http_post(url = nil, body = nil, headers = nil)
      block = Proc.new if block_given?
      http_method :post, url, body, headers, &block
    end

    # Public: Makes an HTTP call.
    #
    # method  - Symbol of the HTTP method.  Example: :put
    # url     - Optional String URL to request.
    # body    - Optional String Body of the POST request.
    # headers - Optional Hash of HTTP headers to set.
    #
    # Examples
    #
    #   http_method(:put, "http://github.com/create", "foobar")
    #   # => <Faraday::Response>
    #
    #   http_method(:put, "http://github.com/create", "foobar",
    #     'Accept': 'application/json')
    #   # => <Faraday::Response>
    #
    #   # Yield the Faraday::Response for more control.
    #   http_method :put, "http://github.com/create" do |req|
    #     req.basic_auth("username", "password")
    #     req.params[:page] = 1 # http://github.com/create?page=1
    #     req.headers['Content-Type'] = 'application/json'
    #     req.body = {:foo => :bar}.to_json
    #   end
    #   # => <Faraday::Response>
    #
    # Yields a Faraday::Request instance.
    # Returns a Faraday::Response instance.
    def http_method(method, url = nil, body = nil, headers = nil)
      block = Proc.new if block_given?

      http.send(method) do |req|
        req.url(url)                if url
        req.headers.update(headers) if headers
        req.body = body             if body
        block.call req if block
      end
    end

    # Public: Lazily loads the Faraday::Connection for the current Service
    # instance.
    #
    # options - Optional Hash of Faraday::Connection options.
    #
    # Returns a Faraday::Connection instance.
    def http(options = {})
      @http ||= begin
        Faraday.new(options) do |b|
          b.request :url_encoded
          b.adapter :net_http
        end
      end
    end

    # Public: Shortens the given URL with bit.ly.
    #
    # url - String URL to be shortened.
    #
    # Returns the String URL response from bit.ly.
    def shorten_url(url)
      res = http_post("http://crash.io", :url => url)
      if res.status == 201
        res.headers['location']
      else
        url
      end
    rescue TimeoutError
      url
    end
  end
end
