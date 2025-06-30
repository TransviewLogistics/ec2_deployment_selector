
# Complete Capistrano integration with ec2_deployment_selector
# Add this to your config/deploy.rb

require 'ec2_deployment_selector'

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

  # Standard server definitions
  selector.selected_instances.each do |instance|
    server instance.public_ip_address, user: "deploy", roles: %w{app}
  end
end

configure_ec2_selector.call('production') if fetch(:stage) == :production

# Custom notification with additional data
task :custom_notify do
  invoke "ec2_deployment_selector:slack:notify", "Custom notification", {
    feature: fetch(:feature_name, "standard"),
    custom_field: "value"
  }
end

# Deployment hooks - use the explicit task name
after :finished, "ec2_deployment_selector:slack:notify"
