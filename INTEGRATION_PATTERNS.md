# Integration Guide

Simple integration patterns for `ec2_deployment_selector` notifications.

## Capistrano Integration (Recommended)

### Basic Setup

Add to `Gemfile`:
```ruby
gem 'ec2_deployment_selector'
```

Add to `config/deploy.rb`:
```ruby
require 'ec2_deployment_selector'
define_slack_notification_tasks
after :finished, :notify_slack
```

Create `config/slack_notifications.yml`:
```yaml
production:
  enabled: true
  webhook_url_env_var: "SLACK_WEBHOOK_URL"
  channel: "#deployments"
  
staging:
  enabled: true
  webhook_url_env_var: "SLACK_WEBHOOK_URL"
  channel: "#staging"
```

### Advanced Usage

```ruby
# Validate before deploy
before :deploy, :validate_slack_config

# Start and completion notifications
before :deploy, :notify_slack_start
after :finished, :notify_slack

# Custom notifications
task :custom_notify do
  run_locally do
    send_deployment_notification(nil, {
      custom_field: "value",
      feature: fetch(:feature_name, "standard")
    })
  end
end
```

## Other Integrations

### Standalone Script
```ruby
require 'ec2_deployment_selector'

notifier = Ec2DeploymentSelector::SlackNotifier.new(
  webhook_url: ENV["SLACK_WEBHOOK_URL"],
  stage: "production"
)

notifier.send_deployment_notification({
  application: "my-app",
  environment: "production",
  user: ENV["USER"]
})
```

### With EC2 Selection
```ruby
selector = Ec2DeploymentSelector::Selector.new(
  access_key_id: ENV["AWS_ACCESS_KEY_ID"],
  secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
  application_name: "my-app",
  track_metadata: true
)

selector.select_instances
selector.send_slack_notification(webhook_url: ENV["SLACK_WEBHOOK_URL"])
```

## Environment Variables

- `SLACK_WEBHOOK_URL`: Your Slack webhook URL (required)
- `SLACK_NOTIFICATIONS_ENABLED`: "true"/"false" (optional)
- `SLACK_CHANNEL`: Override channel (optional)

## Testing

```bash
cap production validate_slack_config
cap production test_slack
```
