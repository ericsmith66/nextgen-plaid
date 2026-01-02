require 'spec_helper'

RSpec.describe SmartProxyApp do
  def app
    SmartProxyApp
  end

  describe 'GET /health' do
    it 'returns ok' do
      get '/health', {}, { 'HTTP_HOST' => 'localhost' }
      expect(last_response).to be_ok
      expect(JSON.parse(last_response.body)).to eq({ 'status' => 'ok' })
    end
  end

  describe 'GET /v1/models' do
    let(:auth_token) { 'test_token' }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('PROXY_AUTH_TOKEN').and_return(auth_token)
    end

    context 'when unauthorized' do
      it 'returns 401' do
        get '/v1/models', {}, { 'HTTP_HOST' => 'localhost' }
        expect(last_response.status).to eq(401)
      end
    end

    context 'when authorized' do
      let(:headers) { { 'HTTP_AUTHORIZATION' => "Bearer #{auth_token}", 'HTTP_HOST' => 'localhost' } }

      it 'returns OpenAI-compatible list of models from Ollama tags' do
        stub_request(:get, 'http://localhost:11434/api/tags')
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: {
              models: [
                {
                  name: 'llama3.1:8b',
                  modified_at: '2026-01-01T00:00:00Z',
                  size: 123,
                  digest: 'sha256:abc',
                  details: { family: 'llama', parameter_size: '8B' }
                }
              ]
            }.to_json
          )

        get '/v1/models', {}, headers
        expect(last_response).to be_ok

        body = JSON.parse(last_response.body)
        expect(body['object']).to eq('list')
        expect(body['data']).to be_an(Array)
        expect(body['data'].first).to include('id' => 'llama3.1:8b', 'object' => 'model', 'owned_by' => 'ollama')
      end
    end
  end

  describe 'POST /proxy/generate' do
    let(:payload) { { 'model' => 'grok-beta', 'messages' => [{ 'role' => 'user', 'content' => 'Hello' }] } }
    let(:auth_token) { 'test_token' }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('PROXY_AUTH_TOKEN').and_return(auth_token)
      allow(ENV).to receive(:[]).with('GROK_API_KEY').and_return('grok_key')
    end

    context 'when unauthorized' do
      it 'returns 401' do
        post '/proxy/generate', payload.to_json, { 'HTTP_HOST' => 'localhost' }
        expect(last_response.status).to eq(401)
      end
    end

    context 'when authorized' do
      let(:headers) { { 'HTTP_AUTHORIZATION' => "Bearer #{auth_token}", 'HTTP_HOST' => 'localhost' } }

      it 'prioritizes GROK_API_KEY_SAP' do
        allow(ENV).to receive(:[]).with('GROK_API_KEY_SAP').and_return('sap_key')
        
        stub_request(:post, "https://api.x.ai/v1/chat/completions")
          .with(headers: { 'Authorization' => 'Bearer sap_key' })
          .to_return(status: 200, body: {}.to_json)

        post '/proxy/generate', payload.to_json, headers
        expect(last_response).to be_ok
      end

      it 'uses session id from headers' do
        request_id = 'test-request-id'
        headers_with_id = headers.merge('HTTP_X_REQUEST_ID' => request_id)
        
        stub_request(:post, "https://api.x.ai/v1/chat/completions")
          .to_return(status: 200, body: {}.to_json)

        post '/proxy/generate', payload.to_json, headers_with_id
        expect(last_response).to be_ok
      end

      it 'isolates concurrent requests (conceptual test)' do
        stub_request(:post, "https://api.x.ai/v1/search/web").to_return(status: 200, body: {}.to_json)
        stub_request(:post, "https://api.x.ai/v1/search/x").to_return(status: 200, body: {}.to_json)

        tool_payload = { 'query' => 'test' }
        post '/proxy/tools', tool_payload.to_json, headers
        id1 = JSON.parse(last_response.body)['session_id']
        
        post '/proxy/tools', tool_payload.to_json, headers
        id2 = JSON.parse(last_response.body)['session_id']
        
        expect(id1).not_to eq(id2)
        expect(id1).not_to be_nil
      end

      it 'forwards the request to Grok' do
        stub_request(:post, "https://api.x.ai/v1/chat/completions")
          .to_return(status: 200, body: { 'choices' => [{ 'message' => { 'content' => 'Hi' } }] }.to_json, headers: { 'Content-Type' => 'application/json' })

        post '/proxy/generate', payload.to_json, headers
        
        expect(last_response).to be_ok
        expect(JSON.parse(last_response.body)).to include('choices')
      end

      it 'anonymizes the request' do
        payload_with_pii = { 'messages' => [{ 'role' => 'user', 'content' => 'My email is test@example.com' }] }
        
        stub_request(:post, "https://api.x.ai/v1/chat/completions")
          .with(body: /My email is \[EMAIL\]/)
          .to_return(status: 200, body: {}.to_json)

        post '/proxy/generate', payload_with_pii.to_json, headers
        expect(last_response).to be_ok
      end
    end
  end

  describe 'POST /v1/chat/completions' do
    let(:auth_token) { 'test_token' }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('PROXY_AUTH_TOKEN').and_return(auth_token)
    end

    context 'when unauthorized' do
      it 'returns 401' do
        post '/v1/chat/completions', { model: 'llama3.1:8b', messages: [ { role: 'user', content: 'Hello' } ] }.to_json, { 'HTTP_HOST' => 'localhost' }
        expect(last_response.status).to eq(401)
      end
    end

    context 'when authorized' do
      let(:headers) { { 'HTTP_AUTHORIZATION' => "Bearer #{auth_token}", 'HTTP_HOST' => 'localhost' } }

      it 'maps Ollama /api/chat response into OpenAI chat.completion format' do
        stub_request(:post, 'http://localhost:11434/api/chat')
          .to_return(
            status: 200,
            headers: { 'Content-Type' => 'application/json' },
            body: {
              model: 'llama3.1:8b',
              created_at: '2026-01-01T00:00:00Z',
              message: { role: 'assistant', content: 'Hi from Ollama' },
              done: true
            }.to_json
          )

        payload = {
          'model' => 'llama3.1:8b',
          'messages' => [ { 'role' => 'user', 'content' => 'Hello' } ],
          'stream' => false
        }

        post '/v1/chat/completions', payload.to_json, headers
        expect(last_response).to be_ok

        body = JSON.parse(last_response.body)
        expect(body['object']).to eq('chat.completion')
        expect(body['choices'].first['message']['content']).to eq('Hi from Ollama')

        # SmartProxy always annotates tool-loop metadata for deterministic callers.
        expect(body.dig('smart_proxy', 'tool_loop', 'loop_count')).to eq(0)
        expect(body.dig('smart_proxy', 'tools_used')).to eq([])
      end

      it 'orchestrates tool_calls server-side (max_loops default)' do
        allow(ENV).to receive(:[]).with('GROK_API_KEY').and_return('grok_key')

        first_upstream = {
          'id' => 'chatcmpl-1',
          'object' => 'chat.completion',
          'created' => 1,
          'model' => 'grok-4',
          'choices' => [
            {
              'index' => 0,
              'finish_reason' => 'tool_calls',
              'message' => {
                'role' => 'assistant',
                'content' => nil,
                'tool_calls' => [
                  {
                    'id' => 'call_1',
                    'type' => 'function',
                    'function' => {
                      'name' => 'proxy_tools',
                      'arguments' => { 'query' => 'test query', 'num_results' => 2 }.to_json
                    }
                  }
                ]
              }
            }
          ],
          'usage' => { 'prompt_tokens' => 1, 'completion_tokens' => 1, 'total_tokens' => 2 }
        }

        second_upstream = {
          'id' => 'chatcmpl-2',
          'object' => 'chat.completion',
          'created' => 2,
          'model' => 'grok-4',
          'choices' => [
            {
              'index' => 0,
              'finish_reason' => 'stop',
              'message' => { 'role' => 'assistant', 'content' => 'Final answer' }
            }
          ],
          'usage' => { 'prompt_tokens' => 1, 'completion_tokens' => 1, 'total_tokens' => 2 }
        }

        stub_request(:post, 'https://api.x.ai/v1/chat/completions')
          .to_return(
            { status: 200, headers: { 'Content-Type' => 'application/json' }, body: first_upstream.to_json },
            { status: 200, headers: { 'Content-Type' => 'application/json' }, body: second_upstream.to_json }
          )

        stub_request(:post, 'https://api.x.ai/v1/search/web')
          .to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: { results: [] }.to_json)
        stub_request(:post, 'https://api.x.ai/v1/search/x')
          .to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: { results: [] }.to_json)

        payload = {
          'model' => 'grok-4',
          'messages' => [ { 'role' => 'user', 'content' => 'Hello' } ],
          'stream' => false
        }

        post '/v1/chat/completions', payload.to_json, headers
        expect(last_response).to be_ok

        body = JSON.parse(last_response.body)
        expect(body['choices'].first['message']['content']).to eq('Final answer')

        expect(body.dig('smart_proxy', 'tool_loop', 'loop_count')).to eq(1)
        expect(body.dig('smart_proxy', 'tools_used')).to include(include('name' => 'proxy_tools', 'tool_call_id' => 'call_1'))
      end

      it 'allows per-request max_loops override via header' do
        allow(ENV).to receive(:[]).with('GROK_API_KEY').and_return('grok_key')

        upstream = {
          'id' => 'chatcmpl-1',
          'object' => 'chat.completion',
          'created' => 1,
          'model' => 'grok-4',
          'choices' => [
            {
              'index' => 0,
              'finish_reason' => 'tool_calls',
              'message' => {
                'role' => 'assistant',
                'content' => nil,
                'tool_calls' => [
                  {
                    'id' => 'call_1',
                    'type' => 'function',
                    'function' => {
                      'name' => 'proxy_tools',
                      'arguments' => { 'query' => 'test query', 'num_results' => 2 }.to_json
                    }
                  }
                ]
              }
            }
          ],
          'usage' => { 'prompt_tokens' => 1, 'completion_tokens' => 1, 'total_tokens' => 2 }
        }

        stub_request(:post, 'https://api.x.ai/v1/chat/completions')
          .to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: upstream.to_json)

        payload = {
          'model' => 'grok-4',
          'messages' => [ { 'role' => 'user', 'content' => 'Hello' } ],
          'stream' => false
        }

        headers_with_override = headers.merge('HTTP_X_SMART_PROXY_MAX_LOOPS' => '0')
        post '/v1/chat/completions', payload.to_json, headers_with_override
        expect(last_response).to be_ok

        body = JSON.parse(last_response.body)
        expect(body.dig('smart_proxy', 'tool_loop', 'max_loops')).to eq(0)
        expect(body.dig('smart_proxy', 'tool_loop', 'stopped')).to eq('max_loops')
      end

      it 'enforces max_loops and returns a response with tool_loop metadata' do
        allow(ENV).to receive(:[]).with('GROK_API_KEY').and_return('grok_key')
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('SMART_PROXY_MAX_LOOPS', '3').and_return('0')

        upstream = {
          'id' => 'chatcmpl-1',
          'object' => 'chat.completion',
          'created' => 1,
          'model' => 'grok-4',
          'choices' => [
            {
              'index' => 0,
              'finish_reason' => 'tool_calls',
              'message' => {
                'role' => 'assistant',
                'content' => nil,
                'tool_calls' => [
                  {
                    'id' => 'call_1',
                    'type' => 'function',
                    'function' => {
                      'name' => 'proxy_tools',
                      'arguments' => { 'query' => 'test query', 'num_results' => 2 }.to_json
                    }
                  }
                ]
              }
            }
          ],
          'usage' => { 'prompt_tokens' => 1, 'completion_tokens' => 1, 'total_tokens' => 2 }
        }

        stub_request(:post, 'https://api.x.ai/v1/chat/completions')
          .to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: upstream.to_json)

        payload = {
          'model' => 'grok-4',
          'messages' => [ { 'role' => 'user', 'content' => 'Hello' } ],
          'stream' => false
        }

        post '/v1/chat/completions', payload.to_json, headers
        expect(last_response).to be_ok

        body = JSON.parse(last_response.body)
        expect(body.dig('smart_proxy', 'tool_loop', 'stopped')).to eq('max_loops')
        expect(body.dig('smart_proxy', 'tool_loop', 'max_loops')).to eq(0)
      end
    end
  end
end
