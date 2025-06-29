require "net/http"
require "json"
require "uri"
require "yaml"

module Ec2DeploymentSelector
  class SlackNotifier
    attr_reader :config, :webhook_url, :stage

    def initialize(config_file_path: nil, stage: nil, webhook_url: nil)
      @stage = stage
      @webhook_url = webhook_url
      @config = load_config(config_file_path)
    end

    def send_deployment_notification(deployment_data = {})
      unless notifications_enabled?
        puts "ℹ️  Slack notifications disabled for #{stage} environment"
        return false
      end

      unless webhook_url_configured?
        puts "⚠️  Slack webhook URL not configured for #{stage}"
        return false
      end

      message = build_message(deployment_data)
      send_message(message)
    end

    def send_custom_message(message_payload)
      unless webhook_url_configured?
        puts "⚠️  Slack webhook URL not configured"
        return false
      end

      send_message(message_payload)
    end

    private

    def load_config(config_file_path)
      if config_file_path && File.exist?(config_file_path)
        config = YAML.load_file(config_file_path)
        stage_config = config[stage.to_s] || config["default"] || {}
      else
        {}
      end
    end

    def notifications_enabled?
      @config["enabled"] != false
    end

    def webhook_url_configured?
      return true if @webhook_url

      webhook_url_env_var = @config["webhook_url_env_var"]
      @webhook_url = ENV[webhook_url_env_var] if webhook_url_env_var

      !@webhook_url.nil? && !@webhook_url.empty?
    end

    def build_message(deployment_data)
      fields = build_fields(deployment_data)

      message = {
        text: build_message_text,
        username: message_username,
        attachments: [
          {
            color: success_color,
            fields: fields,
          },
        ],
      }

      message[:channel] = channel if channel
      message
    end

    def build_fields(deployment_data)
      fields = []

      fields << {title: "Application", value: deployment_data[:application], short: true} if deployment_data[:application]
      fields << {title: "Environment", value: deployment_data[:environment] || stage.to_s.capitalize, short: true} if stage
      fields << {title: "Branch", value: deployment_data[:branch], short: true} if deployment_data[:branch]
      fields << {title: "Deployed by", value: deployment_data[:user], short: true} if deployment_data[:user]
      fields << {title: "Completed at", value: deployment_data[:timestamp], short: false} if deployment_data[:timestamp]

      if deployment_data[:servers] && !deployment_data[:servers].empty?
        server_list = format_servers(deployment_data[:servers])
        fields << {title: "Target Servers", value: server_list, short: false}
      elsif deployment_data[:target_ips] && !deployment_data[:target_ips].strip.empty?
        fields << {title: "Target Servers", value: deployment_data[:target_ips], short: false}
      end

      if deployment_data[:build_url]
        fields << {title: "Pipeline", value: "<#{deployment_data[:build_url]}|View in CircleCI>", short: true}
      elsif deployment_data[:workflow_id]
        circle_url = "https://app.circleci.com/pipelines/workflows/#{deployment_data[:workflow_id]}"
        fields << {title: "Pipeline", value: "<#{circle_url}|View in CircleCI>", short: true}
      end

      fields
    end

    def format_servers(servers)
      if servers.is_a?(Array) && servers.first.is_a?(Hash)
        servers.map { |server|
          "#{server[:name] || 'Unknown'} (#{server[:public_ip] || server[:ip] || 'No IP'})"
        }.join(", ")
      elsif servers.is_a?(Array)
        servers.join(", ")
      else
        servers.to_s
      end
    end

    def build_message_text
      emoji = @config.dig("message", "emoji") || "🚀"
      title = @config.dig("message", "title") || "Deployment Complete!"
      "#{emoji} #{title}"
    end

    def message_username
      @config.dig("message", "username") || "deployment-notifier"
    end

    def success_color
      @config.dig("message", "success_color") || "good"
    end

    def channel
      @config["channel"]
    end

    def timeout
      @config["timeout"] || 10
    end

    def send_message(message_payload)
      uri = URI(@webhook_url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = timeout

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = message_payload.to_json

      response = http.request(request)

      if response.code == "200"
        puts "✅ Slack notification sent successfully to #{channel || "webhook default channel"}"
        true
      else
        puts "⚠️ Slack notification failed: #{response.code} #{response.message}"
        false
      end
    rescue => e
      puts "⚠️ Slack notification error (deployment continued): #{e.message}"
      false
    end
  end
end
