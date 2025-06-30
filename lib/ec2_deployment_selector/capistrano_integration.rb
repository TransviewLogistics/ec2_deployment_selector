require "ec2_deployment_selector/slack_notifier"

module Ec2DeploymentSelector
  module CapistranoIntegration
    @@ec2_instance_metadata = {}

    def self.register_ec2_instances(instances)
      return unless instances

      @@ec2_instance_metadata = {}
      instances.each do |instance|
        public_ip = instance.public_ip_address
        private_ip = instance.private_ip_address

        [public_ip, private_ip].compact.each do |ip|
          @@ec2_instance_metadata[ip] = {
            name: instance.name,
            public_ip: public_ip,
            private_ip: private_ip,
            instance_type: instance.instance_type,
            layers: instance.layers,
            region: instance.region
          }
        end
      end
    end

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
      ["config/slack_notifications.yml", "slack_notifications.yml"].find { |path| File.exist?(path) }
    end

    def collect_deployment_data(additional_data = {})
      revision = fetch(:current_revision, nil) || (`git rev-parse HEAD 2>/dev/null`.strip rescue nil)

      {
        application: fetch(:application, nil),
        branch: fetch(:branch, revision),
        user: ENV.values_at("CIRCLE_USERNAME", "USER", "USERNAME").compact.first || (`whoami`.strip rescue "unknown"),
        timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S UTC"),
        environment: fetch(:stage, "unknown").to_s.capitalize,
        target_ips: ENV["TARGET_IPS"],
        build_url: ENV["CIRCLE_BUILD_URL"],
        workflow_id: ENV["CIRCLE_WORKFLOW_ID"],
        servers: collect_server_info,
        revision: revision,
        previous_revision: fetch(:previous_revision, nil)
      }.merge(additional_data)
    end

    def send_deployment_notification(notifier = nil, additional_data = {})
      notifier ||= create_slack_notifier
      deployment_data = collect_deployment_data(additional_data)
      notifier.send_deployment_notification(deployment_data)
    end

    def define_slack_notification_tasks
      desc "Send Slack notification about deployment completion"
      task :notify_slack do
        run_locally { send_deployment_notification }
      end
    end

    private

    def collect_server_info
      return [] unless respond_to?(:roles) && roles(:all).any?

      roles(:all).map do |server|
        hostname = server.hostname

        server_info = {
          name: hostname,
          ip: hostname,
          public_ip: hostname,  # Slack notifier expects public_ip field
          roles: server.roles.map(&:to_s)
        }

        # Check for EC2 metadata stored during instance selection
        if @@ec2_instance_metadata[hostname]
          metadata = @@ec2_instance_metadata[hostname]
          server_info.merge!({
            name: metadata[:name] || hostname,
            public_ip: metadata[:public_ip] || hostname,
            private_ip: metadata[:private_ip],
            instance_type: metadata[:instance_type],
            layers: metadata[:layers],
            region: metadata[:region]
          })
        end

        server_info
      end
    end
  end
end
