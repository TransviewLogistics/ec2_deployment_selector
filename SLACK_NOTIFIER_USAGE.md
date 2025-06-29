# SlackNotifier Usage Examples

## Basic Usage (Standalone)

```ruby
require 'ec2_deployment_selector'

# Create notifier with webhook URL
notifier = Ec2DeploymentSelector::SlackNotifier.new(
  webhook_url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
  stage: "production"
)

# Send deployment notification
notifier.send_deployment_notification({
  application: "my-app",
  branch: "main",
  user: "deploy-user",
  timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S UTC"),
  servers: ["server1 (10.0.1.1)", "server2 (10.0.1.2)"]
})
```

## Usage with Configuration File

```ruby
# Create config/slack_notifications.yml first (see template)
notifier = Ec2DeploymentSelector::SlackNotifier.new(
  config_file_path: "config/slack_notifications.yml",
  stage: "staging"
)

notifier.send_deployment_notification({
  application: "my-app",
  branch: "develop",
  user: "developer"
})
```

## Capistrano Integration

Add to your `config/deploy.rb`:

```ruby
require 'ec2_deployment_selector'

# Define the notification task
define_slack_notification_task

# Add to deployment flow
after :finished, :notify_slack
```

Or call manually:

```ruby
# In a Capistrano task
task :custom_deploy_task do
  run_locally do
    send_deployment_notification({
      custom_field: "custom_value"
    })
  end
end
```

## Advanced Usage

```ruby
# Custom message with full control
notifier.send_custom_message({
  text: "🎉 Special deployment completed!",
  channel: "#special-channel",
  attachments: [{
    color: "good",
    fields: [
      {title: "Environment", value: "production", short: true},
      {title: "Feature", value: "New payment system", short: true}
    ]
  }]
})
```

## Environment Variables

Set these environment variables:
- `SLACK_WEBHOOK_URL`: Your Slack webhook URL
- `CIRCLE_USERNAME`: Deployment user (auto-detected from CircleCI)
- `CIRCLE_BUILD_URL`: Build URL (auto-detected from CircleCI)
- `CIRCLE_WORKFLOW_ID`: Workflow ID (auto-detected from CircleCI)
- `TARGET_IPS`: Comma-separated list of target server IPs
