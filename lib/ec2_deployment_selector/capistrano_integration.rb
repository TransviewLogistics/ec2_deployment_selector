require "ec2_deployment_selector/slack_notifier"

module Ec2DeploymentSelector
  module CapistranoIntegration
    def create_slack_notifier(config_file_path: nil, webhook_url: nil)
      config_file_path ||= detect_config_file_path
      webhook_url ||= ENV["SLACK_WEBHOOK_URL"]

      SlackNotifier.new(
        config_file_path: config_file_path,
        stage: fetch(:stage),
        webhook_url: webhook_url
      )
    end

    def detect_config_file_path
      potential_paths = [
        File.join(Dir.pwd, "config", "slack_notifications.yml"),
        File.join(File.dirname(fetch(:deploy_to, ".")), "..", "config", "slack_notifications.yml"),
        File.join(Dir.pwd, "slack_notifications.yml"),
        File.join(ENV["HOME"] || ".", ".slack_notifications.yml")
      ]

      potential_paths.find { |path| File.exist?(path) }
    end

    def collect_deployment_data(additional_data = {})
      base_data = {
        application: fetch(:application, nil),
        branch: fetch(:branch, fetch(:current_revision, nil)),
        user: detect_deployment_user,
        timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S UTC"),
        environment: fetch(:stage, "unknown").to_s.capitalize,
        target_ips: ENV["TARGET_IPS"],
        build_url: ENV["CIRCLE_BUILD_URL"],
        workflow_id: ENV["CIRCLE_WORKFLOW_ID"]
      }

      base_data[:servers] = collect_server_info
      base_data.merge!(collect_git_info)
      base_data.merge!(collect_circleci_info)
      base_data.merge(additional_data)
    end

    def send_deployment_notification(notifier = nil, additional_data = {})
      notifier ||= create_slack_notifier
      deployment_data = collect_deployment_data(additional_data)

      puts "📤 Sending Slack deployment notification..."
      result = notifier.send_deployment_notification(deployment_data)

      if result
        puts "✅ Slack notification sent successfully"
      else
        puts "⚠️  Slack notification failed (deployment continued)"
      end

      result
    end

    def send_deployment_start_notification(notifier = nil, additional_data = {})
      notifier ||= create_slack_notifier

      start_data = collect_deployment_data(additional_data).merge({
        status: "started",
        timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S UTC")
      })

      custom_message = {
        text: "🚀 Deployment Started",
        username: notifier.send(:message_username),
        attachments: [
          {
            color: "warning",
            fields: build_notification_fields(start_data)
          }
        ]
      }

      notifier.send_custom_message(custom_message)
    end

    def validate_slack_config(config_file_path: nil)
      validation = SlackNotifier.validate_config(
        config_file_path: config_file_path || detect_config_file_path,
        stage: fetch(:stage)
      )

      if validation[:valid]
        puts "✅ Slack notifications configured and ready"
      else
        puts "⚠️  Slack notification issues: #{validation[:errors].join(', ')}"
        puts "   Deployment will continue without notifications"
      end

      validation
    end

    def test_slack_notification(config_file_path: nil)
      puts "🧪 Testing Slack notification..."

      SlackNotifier.test_notification(
        config_file_path: config_file_path || detect_config_file_path,
        stage: fetch(:stage)
      )
    end

    def define_slack_notification_tasks
      desc "Validate Slack notification configuration"
      task :validate_slack_config do
        run_locally do
          validate_slack_config
        end
      end

      desc "Test Slack notification (sends test message)"
      task :test_slack do
        run_locally do
          test_slack_notification
        end
      end

      desc "Send Slack notification about deployment start"
      task :notify_slack_start do
        run_locally do
          send_deployment_start_notification
        end
      end

      desc "Send Slack notification about deployment completion"
      task :notify_slack do
        run_locally do
          send_deployment_notification
        end
      end
    end

    private

    def detect_deployment_user
      ENV["CIRCLE_USERNAME"] ||
      ENV["USER"] ||
      ENV["USERNAME"] ||
      `whoami`.strip rescue "unknown"
    end

    def collect_server_info
      servers_info = []

      if respond_to?(:roles) && roles(:all).any?
        roles(:all).each do |server|
          servers_info << {
            name: server.hostname,
            ip: server.hostname,
            roles: server.roles.map(&:to_s)
          }
        end
      elsif defined?(fetch) && fetch(:deployed_servers_info, nil)
        servers_info = fetch(:deployed_servers_info)
      end

      servers_info
    end

    def collect_git_info
      git_info = {}

      begin
        if respond_to?(:fetch)
          git_info[:revision] = fetch(:current_revision, nil)
          git_info[:previous_revision] = fetch(:previous_revision, nil)
        end

        unless git_info[:revision]
          git_info[:revision] = `git rev-parse HEAD 2>/dev/null`.strip rescue nil
        end

        unless git_info[:branch]
          git_info[:branch] = `git branch --show-current 2>/dev/null`.strip rescue nil
        end
      rescue => e
        # Git info is optional, don't fail if unavailable
      end

      git_info.compact
    end

    def collect_circleci_info
      circleci_info = {}

      circleci_info[:build_num] = ENV["CIRCLE_BUILD_NUM"] if ENV["CIRCLE_BUILD_NUM"]
      circleci_info[:job] = ENV["CIRCLE_JOB"] if ENV["CIRCLE_JOB"]
      circleci_info[:pr_number] = ENV["CIRCLE_PR_NUMBER"] if ENV["CIRCLE_PR_NUMBER"]
      circleci_info[:repository_url] = ENV["CIRCLE_REPOSITORY_URL"] if ENV["CIRCLE_REPOSITORY_URL"]

      circleci_info
    end

    def build_notification_fields(data)
      fields = []

      fields << {title: "Application", value: data[:application], short: true} if data[:application]
      fields << {title: "Environment", value: data[:environment], short: true} if data[:environment]
      fields << {title: "Branch", value: data[:branch], short: true} if data[:branch]
      fields << {title: "User", value: data[:user], short: true} if data[:user]
      fields << {title: "Status", value: data[:status].capitalize, short: true} if data[:status]

      if data[:build_url]
        fields << {title: "Pipeline", value: "<#{data[:build_url]}|View in CircleCI>", short: true}
      elsif data[:workflow_id]
        circle_url = "https://app.circleci.com/pipelines/workflows/#{data[:workflow_id]}"
        fields << {title: "Pipeline", value: "<#{circle_url}|View in CircleCI>", short: true}
      end

      fields
    end
  end
end
