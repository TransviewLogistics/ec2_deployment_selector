require 'ec2_deployment_selector'

# Basic usage (backwards compatible - no metadata tracking)
selector = Ec2DeploymentSelector::Selector.new(
  access_key_id: ENV["ACCESS_KEY_ID"],
  secret_access_key: ENV["SECRET_ACCESS_KEY"],
  application_name: "my-app",
  filters: { "ENV_Type" => "production" }
)

# Enhanced usage with metadata tracking enabled
selector_with_metadata = Ec2DeploymentSelector::Selector.new(
  access_key_id: ENV["ACCESS_KEY_ID"],
  secret_access_key: ENV["SECRET_ACCESS_KEY"],
  application_name: "my-app",
  filters: { "ENV_Type" => "production" },
  track_metadata: true  # Enable metadata collection
)

# Perform instance selection
selector_with_metadata.render_all_instances
selector_with_metadata.prompt_select_instances
selector_with_metadata.confirm_selected_instances

# Collect deployment metadata
metadata = selector_with_metadata.collect_deployment_metadata

puts "Deployment Metadata:"
puts "  Application: #{metadata[:application]}"
puts "  Environment: #{metadata[:environment]}"
puts "  Instance Count: #{metadata[:instance_count]}"
puts "  Regions: #{metadata[:regions].join(', ')}"
puts "  Target IPs: #{metadata[:target_ips]}"

# Get data formatted for notifications
notification_data = selector_with_metadata.deployment_data_for_notifications

# Method 1: Create notifier and send manually
notifier = Ec2DeploymentSelector::SlackNotifier.new(
  webhook_url: ENV["SLACK_WEBHOOK_URL"],
  stage: "production"
)
notifier.send_deployment_notification(notification_data)

# Method 2: Use convenience method (recommended)
selector_with_metadata.send_slack_notification(
  webhook_url: ENV["SLACK_WEBHOOK_URL"],
  stage: "production"
)
