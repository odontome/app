# frozen_string_literal: true

module AgentOauthTestClients
  CHATGPT_ID = 'https://chatgpt.com/oauth/client.json'
  CHATGPT_REDIRECT = 'https://chatgpt.com/connector_platform_oauth_redirect'
  VERIFIER = 'test-verifier-' + ('a' * 43)
  CLIENTS = {
    # Snapshot of ChatGPT's published metadata, including its public-client fallback.
    chatgpt: {
      'client_id' => CHATGPT_ID, 'client_name' => 'ChatGPT', 'redirect_uris' => [CHATGPT_REDIRECT],
      'grant_types' => %w[authorization_code refresh_token], 'response_types' => ['code'],
      'token_endpoint_auth_method' => 'private_key_jwt', 'token_endpoint_auth_methods_supported' => %w[none private_key_jwt]
    },
    # Synthetic hosted Claude-shaped client; not a claim about its production CIMD URL.
    hosted_claude: {
      'client_id' => 'https://hosted-claude.example/oauth/client.json', 'client_name' => 'Claude',
      'redirect_uris' => ['https://callback.claude-example.net/oauth/return?source=mcp'],
      'grant_types' => %w[authorization_code refresh_token], 'token_endpoint_auth_method' => 'none'
    },
    claude_code: {
      'client_id' => 'https://claude.ai/oauth/claude-code-client-metadata', 'client_name' => 'Claude Code',
      'redirect_uris' => ['http://localhost/callback', 'http://127.0.0.1/callback'],
      'grant_types' => %w[authorization_code refresh_token], 'token_endpoint_auth_method' => 'none'
    },
    other: {
      'client_id' => 'https://independent.example/metadata.json', 'client_name' => 'Another assistant',
      'redirect_uris' => ['https://unrelated.example/return'],
      'grant_types' => %w[authorization_code refresh_token]
    }
  }.freeze

  def with_oauth_clients
    download = lambda do |url|
      document = CLIENTS.values.find { |client| client['client_id'] == url.to_s }
      [document.deep_dup, 0] if document
    end
    AgentOauthClient.stub(:download, download) { yield }
  end
end
