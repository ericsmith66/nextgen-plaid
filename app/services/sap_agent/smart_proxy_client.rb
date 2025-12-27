class SapAgent::SmartProxyClient
  def self.research(query, num_results: 5, request_id: nil)
    port = ENV['SMART_PROXY_PORT'] || 4567
    url = "http://localhost:#{port}/proxy/tools"
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 60 # Tool calls can be slow

    auth_token = ENV['PROXY_AUTH_TOKEN']

    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    request['Authorization'] = "Bearer #{auth_token}" if auth_token
    request['X-Request-ID'] = request_id if request_id
    
    request.body = {
      query: query,
      num_results: num_results
    }.to_json

    response = http.request(request)

    if response.code == '200'
      JSON.parse(response.body)
    else
      Rails.logger.error("SmartProxy Tools Error: #{response.code} - #{response.body}")
      { error: "SmartProxy returned #{response.code}", confidence: 0 }
    end
  rescue => e
    Rails.logger.error("SmartProxy Tools Connection Error: #{e.message}")
    { error: "Could not connect to SmartProxy.", confidence: 0 }
  end
end
