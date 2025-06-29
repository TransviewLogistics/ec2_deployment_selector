require "ec2_deployment_selector/slack_notifier"

module Ec2DeploymentSelector
  module CapistranoIntegration
    def create_slack_notifier(config_file_path: nil)
      config_file_path ||= File.join(File.dirname(fetch(:deploy_to, ".")), "..", "config", "slack_notifications.yml")
      config_file_path = File.join(Dir.pwd, "config", "slack_notifications.yml") unless File.exist?(config_file_path)

      SlackNotifier.new(
        config_file_path: config_file_path,
        stage: fetch(:stage),
        webhook_url: ENV["SLACK_WEBHOOK_URL"]
      )
    end

    def send_deployment_notification(notifier = nil, additional_data = {})
      notifier ||= create_slack_notifier

      deployment_data = {
        application: fetch(:application),
        branch: fetch(:branch),
        user: ENV["CIRCLE_USERNAME"] || `whoami`.strip,
        timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S UTC"),
        environment: fetch(:stage).to_s.capitalize,
        target_ips: ENV["TARGET_IPS"],
        servers: fetch(:deployed_servers_info, []),
        build_url: ENV["CIRCLE_BUILD_URL"],
        workflow_id: ENV["CIRCLE_WORKFLOW_ID"]
      }.merge(additional_data)

      notifier.send_deployment_notification(deployment_data)
    end

    def define_slack_notification_task
      desc "Send Slack notification about deployment completion"
      task :notify_slack do
        run_locally do
          send_deployment_notification
        end
      end
    end
  end
end

if defined?(Capistrano::DSL)
  extend Ec2DeploymentSelector::CapistranoIntegration
end
