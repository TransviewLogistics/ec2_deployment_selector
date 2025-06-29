require "net/http"
require "json"
require "uri"
require "yaml"

module Ec2DeploymentSelector
  class SlackNotifier
    attr_reader :config, :webhook_url, :stage

    def self.validate_config(config_file_path: nil, stage: nil)
      notifier = new(config_file_path: config_file_path, stage: stage)

      errors = []
      errors << "Notifications are disabled" unless notifier.send(:notifications_enabled?)
      errors << "Webhook URL not configured" unless notifier.send(:webhook_url_configured?)
      errors << "Invalid webhook URL format" unless notifier.send(:valid_webhook_url?)

      { valid: errors.empty?, errors: errors }
    end

    def self.test_notification(config_file_path: nil, stage: nil, webhook_url: nil)
      notifier = new(config_file_path: config_file_path, stage: stage, webhook_url: webhook_url)

      test_data = {
        application: "test-app",
        environment: stage || "test",
        branch: "test-branch",
        user: "test-user",
        timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")
      }

      notifier.send_deployment_notification(test_data)
    end

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

      unless valid_webhook_url?
        puts "⚠️  Invalid Slack webhook URL format"
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
      config = load_yaml_config(config_file_path)
      merge_env_config(config)
    end

    def load_yaml_config(config_file_path)
      if config_file_path && File.exist?(config_file_path)
        config = YAML.load_file(config_file_path)
        config[stage.to_s] || config["default"] || {}
      else
        {}
      end
    end

    def merge_env_config(config)
      env_config = {}

      # Core settings
      env_config["enabled"] = ENV["SLACK_NOTIFICATIONS_ENABLED"] == "true" if ENV["SLACK_NOTIFICATIONS_ENABLED"]
      env_config["webhook_url_env_var"] = ENV["SLACK_WEBHOOK_URL_ENV_VAR"] if ENV["SLACK_WEBHOOK_URL_ENV_VAR"]
      env_config["channel"] = ENV["SLACK_CHANNEL"] if ENV["SLACK_CHANNEL"]

      # Network settings with validation
      env_config["timeout"] = parse_positive_int(ENV["SLACK_TIMEOUT"], 10) if ENV["SLACK_TIMEOUT"]
      env_config["retry_attempts"] = parse_positive_int(ENV["SLACK_RETRY_ATTEMPTS"], 3) if ENV["SLACK_RETRY_ATTEMPTS"]
      env_config["retry_delay"] = parse_positive_int(ENV["SLACK_RETRY_DELAY"], 1) if ENV["SLACK_RETRY_DELAY"]

      # Message settings
      if ENV["SLACK_USERNAME"] || ENV["SLACK_EMOJI"] || ENV["SLACK_TITLE"] || ENV["SLACK_COLOR"]
        env_config["message"] = {}
        env_config["message"]["username"] = ENV["SLACK_USERNAME"] if ENV["SLACK_USERNAME"]
        env_config["message"]["emoji"] = ENV["SLACK_EMOJI"] if ENV["SLACK_EMOJI"]
        env_config["message"]["title"] = ENV["SLACK_TITLE"] if ENV["SLACK_TITLE"]
        env_config["message"]["success_color"] = ENV["SLACK_COLOR"] if ENV["SLACK_COLOR"]
      end

      config.merge(env_config)
    end

    def parse_positive_int(value, default)
      parsed = value.to_i
      parsed > 0 ? parsed : default
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

    def valid_webhook_url?
      return false unless @webhook_url

      uri = URI.parse(@webhook_url)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
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

    def retry_attempts
      @config["retry_attempts"] || 3
    end

    def retry_delay
      @config["retry_delay"] || 1
    end

    def send_message(message_payload)
      attempt = 1

      loop do
        begin
          response = send_http_request(message_payload)

          if response.code == "200"
            puts "✅ Slack notification sent successfully to #{channel || "webhook default channel"}"
            return true
          else
            error_msg = "#{response.code} #{response.message}"

            if attempt < retry_attempts
              puts "⚠️ Slack notification failed (#{error_msg}), retrying in #{retry_delay}s... (attempt #{attempt}/#{retry_attempts})"
              sleep(retry_delay)
              attempt += 1
            else
              puts "⚠️ Slack notification failed after #{retry_attempts} attempts: #{error_msg}"
              return false
            end
          end
        rescue => e
          if attempt < retry_attempts
            puts "⚠️ Slack notification error, retrying in #{retry_delay}s... (attempt #{attempt}/#{retry_attempts}): #{e.message}"
            sleep(retry_delay)
            attempt += 1
          else
            puts "⚠️ Slack notification error after #{retry_attempts} attempts (deployment continued): #{e.message}"
            return false
          end
        end
      end
    end

    def send_http_request(message_payload)
      uri = URI(@webhook_url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.read_timeout = timeout
      http.open_timeout = timeout

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["User-Agent"] = "ec2-deployment-selector/#{defined?(Ec2DeploymentSelector::VERSION) ? Ec2DeploymentSelector::VERSION : '1.0.0'}"
      request.body = message_payload.to_json

      http.request(request)
    rescue Net::TimeoutError => e
      raise "Request timeout after #{timeout}s: #{e.message}"
    rescue SocketError => e
      raise "Network error: #{e.message}"
    rescue OpenSSL::SSL::SSLError => e
      raise "SSL error: #{e.message}"
    rescue => e
      raise "HTTP request failed: #{e.message}"
    end
  end
end
