# frozen_string_literal: true

module Api
  module Agent
    class McpController < BaseController
      SERVER_INFO = { name: "odontome", version: "1.0.0" }.freeze

      ALLOWED_ORIGINS = %w[
        https://claude.ai
        https://claude.com
        https://chatgpt.com
      ].freeze

      skip_before_action :authenticate_agent!, only: [:preflight, :unsupported_stream]
      prepend_before_action :check_origin_and_set_cors_headers

      rate_limit to: 120, within: 1.minute,
                 by: -> { @practice&.id || request.remote_ip },
                 with: -> { render_jsonrpc_error(nil, -32000, I18n.t("agents.mcp.errors.rate_limited"), status: :too_many_requests) },
                 only: :create

      def preflight
        head :no_content
      end

      def unsupported_stream
        response.headers['Allow'] = 'POST, DELETE, OPTIONS'
        head :method_not_allowed
      end

      def destroy
        head :ok
      end

      def create
        body = parse_body
        return if performed?
        unless body['params'].nil? || body['params'].is_a?(Hash)
          return render_jsonrpc_error(body['id'], -32602, I18n.t("agents.mcp.errors.invalid_request"))
        end

        method = body["method"].to_s
        id = body["id"]

        case method
        when "initialize"
          handle_initialize(id, body['params'] || {})
        when "notifications/initialized"
          head :accepted
        when "tools/list"
          handle_tools_list(id)
        when "tools/call"
          handle_tools_call(id, body["params"] || {})
        else
          render_jsonrpc_error(id, -32601, I18n.t("agents.mcp.errors.method_not_found"))
        end
      end

      private

      MAX_BODY_SIZE = 1.megabyte

      def parse_body
        body_str = request.body.read(MAX_BODY_SIZE + 1)

        if body_str && body_str.bytesize > MAX_BODY_SIZE
          render_jsonrpc_error(nil, -32600, I18n.t("agents.mcp.errors.request_too_large"))
          return nil
        end

        parsed = JSON.parse(body_str.to_s)

        unless parsed.is_a?(Hash)
          render_jsonrpc_error(nil, -32600, I18n.t("agents.mcp.errors.invalid_request"))
          return nil
        end

        parsed
      rescue JSON::ParserError
        render_jsonrpc_error(nil, -32700, I18n.t("agents.mcp.errors.parse_error"))
        nil
      end

      def handle_initialize(id, params)
        version = params['protocolVersion']
        unless version.is_a?(String) && version.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          return render_jsonrpc_error(id, -32602, I18n.t("agents.mcp.errors.invalid_request"))
        end

        render json: {
          jsonrpc: "2.0",
          id: id,
          result: {
            protocolVersion: version,
            capabilities: { tools: { listChanged: false } },
            serverInfo: SERVER_INFO,
            instructions: Mcp::Instructions.for(@practice)
          }
        }
      end

      def handle_tools_list(id)
        render json: {
          jsonrpc: "2.0",
          id: id,
          result: { tools: Mcp::ToolRegistry.definitions }
        }
      end

      def handle_tools_call(id, params)
        tool_name = params["name"].to_s
        arguments = params["arguments"] || {}

        executor = Mcp::ToolExecutor.new(@practice)
        result = executor.call(tool_name, arguments)

        render json: { jsonrpc: "2.0", id: id, result: result }
      end

      def check_origin_and_set_cors_headers
        origin = request.headers["Origin"].to_s
        return if origin.empty?

        allowed = ALLOWED_ORIGINS + ENV.fetch('MCP_ALLOWED_ORIGINS', '').split(',').map(&:strip) + [request.base_url]
        return head :forbidden unless allowed.include?(origin)

        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers['Vary'] = 'Origin'
        response.headers["Access-Control-Allow-Methods"] = "POST, DELETE, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, MCP-Protocol-Version"
        response.headers['Access-Control-Expose-Headers'] = 'WWW-Authenticate'
        response.headers["Access-Control-Max-Age"] = "86400"
      end

      def render_jsonrpc_error(id, code, message, status: :ok)
        render json: {
          jsonrpc: "2.0",
          id: id,
          error: { code: code, message: message }
        }, status: status
      end
    end
  end
end
