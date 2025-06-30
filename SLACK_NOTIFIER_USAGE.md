# Slack Notifier Usage

Simple deployment notifications with automatic EC2 metadata detection.

## Quick Setup

**1. Add to deploy.rb:**
```ruby
require "ec2_deployment_selector"

# Hook into deployment lifecycle (you control when)
after 'deploy:finished', 'ec2_deployment_selector:slack:notify'
```

**2. Set environment variable:**
```bash
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
```

That's it! Notifications automatically include rich EC2 metadata when using the gem's instance selector.

## Features

- **Automatic EC2 metadata** - Instance names, types, regions automatically included in notifications
- **Zero configuration** - Works with just a webhook URL
- **Environment-specific settings** - Optional YAML configuration per environment
- **Rich deployment context** - Git branch, user, timestamp, target servers

## Configuration

### Environment Variables
```bash
# Required
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...

# Optional
SLACK_CHANNEL=#deployments
SLACK_USERNAME=Deploy Bot
SLACK_EMOJI=🚀
SLACK_TITLE=Deployment Complete!
```

### YAML File (Optional)
Create `config/slack_notifications.yml` for per-environment settings:
```yaml
production:
  channel: "#production-alerts"
  username: "Production Bot"
```

## Built-in Defaults
- Channel: `#deployments`
- Username: `Deploy Bot`
- Emoji: `🚀`
- Title: `Deployment Complete!`
- Color: `good` (green)

## Available Tasks
```bash
cap production ec2_deployment_selector:slack:notify  # Send deployment notification
```

## Direct Usage
```ruby
notifier = Ec2DeploymentSelector::SlackNotifier.new(stage: "production")
notifier.send_deployment_notification({
  application: "my-app",
  environment: "production",
  branch: "main"
})
```
