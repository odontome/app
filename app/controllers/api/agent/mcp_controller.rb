# frozen_string_literal: true

module Api
  module Agent
    class McpController < BaseController
      PROTOCOL_VERSION = "2025-11-25"
      SERVER_INFO = { name: "odontome", version: "1.0.0" }.freeze

      def destroy
        head :ok
      end

      def create
        body = parse_body
        return if performed?

        method = body["method"].to_s
        id = body["id"]

        case method
        when "initialize"
          handle_initialize(id)
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

      def parse_body
        JSON.parse(request.body.read)
      rescue JSON::ParserError
        render_jsonrpc_error(nil, -32700, I18n.t("agents.mcp.errors.parse_error"))
        nil
      end

      def handle_initialize(id)
        render json: {
          jsonrpc: "2.0",
          id: id,
          result: {
            protocolVersion: PROTOCOL_VERSION,
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
