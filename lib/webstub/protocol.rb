module WebStub
  class Protocol < NSURLProtocol
    def self.add_stub(*args)
      registry.add_stub(*args)
    end

    def self.canInitWithRequest(request)
      if stub_for(request)
        return true
      end

      ! network_access_allowed?
    end

    def self.canonicalRequestForRequest(request)
      request
    end

    def self.disable_network_access!
      @network_access = false
    end

    def self.enable_network_access!
      @network_access = true
    end

    def self.network_access_allowed?
      @network_access.nil? ? true : @network_access
    end

    def self.reset_stubs
      registry.reset
    end

    def startLoading
      request = self.request
      client = self.client
    
      unless stub = self.class.stub_for(request)
        error = NSError.errorWithDomain("WebStub", code:0, userInfo:{ NSLocalizedDescriptionKey: "network access is not permitted!"})
        client.URLProtocol(self, didFailWithError:error)

        return
      end

      response = NSHTTPURLResponse.alloc.initWithURL(request.URL,
                                                     statusCode:200,
                                                     HTTPVersion:"HTTP/1.1",
                                                     headerFields:stub.response_headers)

      client.URLProtocol(self, didReceiveResponse:response, cacheStoragePolicy:NSURLCacheStorageNotAllowed)
      client.URLProtocol(self, didLoadData:stub.response_body.dataUsingEncoding(NSUTF8StringEncoding))
      client.URLProtocolDidFinishLoading(self)
    end

    def stopLoading
    end

  private

    def self.registry
      @registry ||= Registry.new()
    end

    def self.stub_for(request)
      options = {}
      if request.HTTPBody
        options[:body] = parse_body(request)
      end

      registry.stub_matching(request.HTTPMethod, request.URL.absoluteString, options)
    end

    def self.parse_body(request)
      content_type = nil

      request.allHTTPHeaderFields.each do |key, value|
        if key.downcase == "content-type"
          content_type = value
          break
        end
      end

      body = NSString.alloc.initWithData(request.HTTPBody, encoding:NSUTF8StringEncoding)

      case content_type
      when /application\/x-www-form-urlencoded/
        URI.decode_www_form(body)
      else
        body
      end
    end
  end
end

NSURLProtocol.registerClass(WebStub::Protocol)