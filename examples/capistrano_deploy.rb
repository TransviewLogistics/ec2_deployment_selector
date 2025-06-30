
# Complete Capistrano integration with ec2_deployment_selector
# Add this to your config/deploy.rb

require 'ec2_deployment_selector'

# Include Capistrano integration methods
include Ec2DeploymentSelector::CapistranoIntegration

# Define notification tasks (makes Slack tasks available in Capistrano context)
define_slack_notification_tasks

# EC2 instance selection
configure_ec2_selector = ->(env) do
  selector = Ec2DeploymentSelector::Selector.new(
    access_key_id: ENV["ACCESS_KEY_ID"],
    secret_access_key: ENV["SECRET_ACCESS_KEY"],
    application_name: fetch(:application),
    filters: { "ENV_Type" => env }
  )

  selector.render_all_instances
  selector.prompt_select_instances unless ENV["NON_INTERACTIVE"] == "true"

  # Standard server definitions (EC2 metadata automatically captured for Slack notifications)
  selector.selected_instances.each do |instance|
    server instance.public_ip_address, user: "deploy", roles: %w{app}
  end
end

configure_ec2_selector.call('production') if fetch(:stage) == :production

# Custom notification with additional data
task :custom_notify do
  run_locally do
    send_deployment_notification(nil, {
      feature: fetch(:feature_name, "standard"),
      custom_field: "value"
    })
  end
end

# Deployment hooks
after :finished, :notify_slack
