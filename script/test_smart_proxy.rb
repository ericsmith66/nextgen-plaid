require 'net/http'
require 'json'
require 'dotenv'
Dotenv.load

def test_proxy
  token = ENV['PROXY_AUTH_TOKEN'] || 'your_secure_proxy_token_here'
  port = ENV['SMART_PROXY_PORT'] || 4567
  url = "http://localhost:#{port}/proxy/generate"

  puts "--- Testing Smart Proxy Connection ---"
  puts "URL: #{url}"
  puts "Token: #{token}"

  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = 60

  request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
  request['Authorization'] = "Bearer #{token}"
  
  # Note: The proxy expects a payload that it will forward to Grok
  # Current GrokClient expects a chat completions payload
  request.body = {
    model: 'grok-4',
    messages: [
      { role: 'system', content: 'You are a helpful assistant.' },
      { role: 'user', content: 'Hello! Respond with "OK" if you can hear me.' }
    ]
  }.to_json

  begin
    response = http.request(request)
    puts "Status: #{response.code}"
    puts "Body: #{response.body}"
    
    if response.code == '200'
      puts "\n✅ SUCCESS: Proxy is working and communicating with Grok!"
    else
      puts "\n❌ FAILURE: Proxy returned error code #{response.code}"
    end
  rescue => e
    puts "\n❌ ERROR: Could not connect to proxy: #{e.message}"
  end
end

test_proxy
