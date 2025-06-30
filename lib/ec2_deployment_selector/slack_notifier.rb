require "net/http"
require "json"
require "uri"
require "yaml"

module Ec2DeploymentSelector
  class SlackNotifier
    def initialize(config_file_path: nil, stage: nil, webhook_url: nil)
      @stage = stage
      @webhook_url = webhook_url
      @config = {
        "enabled" => true,
        "channel" => "#qa_and_deployments",
        "username" => "Deploy Bot",
        "emoji" => "🚀",
        "title" => "Deployment Complete!",
        "color" => "good"
      }

      # Load YAML config if file exists
      if config_file_path && File.exist?(config_file_path)
        yaml_config = YAML.load_file(config_file_path)
        stage_config = yaml_config[stage.to_s] || yaml_config["default"] || {}
        @config.merge!(stage_config)
      end

      # Override with environment variables
      %w[enabled channel username emoji title color].each do |key|
        env_key = key == "enabled" ? "SLACK_NOTIFICATIONS_ENABLED" : "SLACK_#{key.upcase}"
        @config[key] = key == "enabled" ? ENV[env_key] == "true" : ENV[env_key] if ENV[env_key]
      end
    end

    def send_deployment_notification(deployment_data = {})
      return false unless notifications_enabled? && webhook_url_valid?

      message = build_message(deployment_data)
      send_message(message)
    end

    def send_custom_message(message_payload)
      return false unless webhook_url_valid?
      send_message(message_payload)
    end

    private

    def notifications_enabled?
      @config["enabled"] != false
    end

    def webhook_url_valid?
      @webhook_url ||= ENV["SLACK_WEBHOOK_URL"]
      return false if @webhook_url.to_s.empty?

      URI.parse(@webhook_url).is_a?(URI::HTTP)
    rescue URI::InvalidURIError
      false
    end

    def build_message(deployment_data)
      fields = build_fields(deployment_data)

      message = {
        text: "#{@config["emoji"]} #{@config["title"]}",
        username: ENV["SLACK_USERNAME"] || @config["username"],
        attachments: [{ color: @config["color"], fields: fields }]
      }

      channel = ENV["SLACK_CHANNEL"] || @config["channel"]
      message[:channel] = channel if channel
      message
    end

    def build_fields(deployment_data)
      fields = []

      # Basic deployment info
      {
        "Application" => deployment_data[:application],
        "Environment" => deployment_data[:environment] || @stage&.to_s&.capitalize,
        "Branch" => deployment_data[:branch],
        "Revision" => deployment_data[:revision] && (deployment_data[:revision].length > 8 ? deployment_data[:revision][0..7] : deployment_data[:revision]),
        "Deployed by" => deployment_data[:user]
      }.each { |title, value| fields << {title: title, value: value, short: true} if value }

      # Timestamp
      fields << {title: "Completed at", value: deployment_data[:timestamp], short: false} if deployment_data[:timestamp]

      # Servers
      if deployment_data[:servers]&.any?
        fields << {title: "Target Servers", value: format_servers(deployment_data[:servers]), short: false}
      elsif deployment_data[:target_ips] && !deployment_data[:target_ips].strip.empty?
        fields << {title: "Target Servers", value: deployment_data[:target_ips], short: false}
      end

      # Pipeline
      if deployment_data[:build_url]
        fields << {title: "Pipeline", value: "<#{deployment_data[:build_url]}|View in CircleCI>", short: true}
      elsif deployment_data[:workflow_id]
        url = "https://app.circleci.com/pipelines/workflows/#{deployment_data[:workflow_id]}"
        fields << {title: "Pipeline", value: "<#{url}|View in CircleCI>", short: true}
      end

      fields
    end

    def format_servers(servers)
      return servers.to_s unless servers.is_a?(Array)
      return servers.join(", ") unless servers.first.is_a?(Hash)

      servers.map { |server|
        name = server[:name] || 'Unknown'
        ip = server[:public_ip] || server[:ip] || 'No IP'
        metadata = [server[:layers], server[:instance_type], server[:region]].compact.reject(&:empty?)
        metadata.any? ? "#{name} (#{ip}) [#{metadata.join(', ')}]" : "#{name} (#{ip})"
      }.join(", ")
    end

    def send_message(message_payload)
      3.times do |attempt|
        begin
          response = send_http_request(message_payload)
          return response.code == "200"
        rescue => e
          sleep(1) unless attempt == 2
        end
      end
      false
    end

    def send_http_request(message_payload)
      uri = URI(@webhook_url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.read_timeout = 10
      http.open_timeout = 10

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = message_payload.to_json

      http.request(request)
    end
  end
end
