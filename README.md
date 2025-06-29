# Ec2DeploymentSelector

EC2 Deployment Selector is a Ruby gem that provides deployment tooling for Amazon EC2 environments.

## Features

### 🎯 EC2 Instance Selection
- Fetch EC2 instances across multiple AWS regions
- Filter instances by application name and custom tags
- Interactive and non-interactive selection modes
- Capistrano integration for deployment automation

### 📤 Slack Notifications
- Deployment notifications with comprehensive data collection
- Capistrano integration with automatic data collection
- Configurable via YAML files or environment variables
- Built-in retry logic, validation, and error handling

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ec2_deployment_selector'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install ec2_deployment_selector

## Quick Start

### EC2 Instance Selection

```ruby
require "ec2_deployment_selector"

selector = Ec2DeploymentSelector::Selector.new(
  access_key_id: ENV["ACCESS_KEY_ID"],
  secret_access_key: ENV["SECRET_ACCESS_KEY"],
  application_name: "my-app",
  filters: { "ENV_Type" => "production" }
)

selector.render_all_instances
```

### Slack Notifications

```ruby
require "ec2_deployment_selector"

# Basic notification
notifier = Ec2DeploymentSelector::SlackNotifier.new(
  webhook_url: ENV["SLACK_WEBHOOK_URL"],
  stage: "production"
)

notifier.send_deployment_notification({
  application: "my-app",
  branch: "main",
  user: "deployer"
})
```

### Capistrano Integration (Notifications)

Add to your `config/deploy.rb`:

```ruby
require 'ec2_deployment_selector'

define_slack_notification_tasks
after :finished, :notify_slack
```

### Usage

### Basic Setup

```ruby
require "ec2_deployment_selector"

configure_ec2_selector = ->(env) do
  ec2_deployment_selector = Ec2DeploymentSelector::Selector.new(
    access_key_id: ENV["ACCESS_KEY_ID"],
    secret_access_key: ENV["SECRET_ACCESS_KEY"],
    application_name: fetch(:application),
    filters: { "ENV_Type" => env }
  )

  ec2_deployment_selector.render_all_instances

  if ENV["NON_INTERACTIVE"] == "true"
    if ENV["TARGET_IPS"] && !ENV["TARGET_IPS"].empty?
      target_ips = ENV["TARGET_IPS"].split(",").map(&:strip)
      all_instances = ec2_deployment_selector.instances || []
      ip_matching_instances = all_instances.select { |instance|
        target_ips.include?(instance.public_ip_address) || target_ips.include?(instance.private_ip_address)
      }
      selected_instances = ip_matching_instances.select(&:deployable?)
      ec2_deployment_selector.selected_instances = selected_instances
    else
      deployable_instances = ec2_deployment_selector.instances.select(&:deployable?)
      ec2_deployment_selector.selected_instances = deployable_instances
    end
  else
    ec2_deployment_selector.prompt_select_instances
    ec2_deployment_selector.confirm_selected_instances
  end

  ec2_deployment_selector.selected_instances.each do |instance|
    server instance.public_ip_address, user: "deploy", roles: %w{app}
  end
end

configure_ec2_selector.call('production') if fetch(:stage) == :production
configure_ec2_selector.call('staging') if fetch(:stage) == :staging
```

### Target IP Filtering

Deploy to specific instances by IP:

```bash
NON_INTERACTIVE=true TARGET_IPS="123.123.123.123,192.168.123.123" bundle exec cap staging deploy
```

### Non-Interactive Mode

For CI/CD pipelines:

```bash
NON_INTERACTIVE=true bundle exec cap production deploy
```

## Slack Notifications

The gem includes Slack notification capabilities.

### Configuration

Create `config/slack_notifications.yml`:

```yaml
production:
  enabled: true
  webhook_url_env_var: "SLACK_WEBHOOK_URL"
  channel: "#deployments"
  message:
    username: "deployment-bot"
    emoji: "🚀"
```

### Available Capistrano Tasks

```bash
cap production validate_slack_config  # Validate configuration
cap production test_slack             # Send test notification
cap production notify_slack_start     # Deployment start notification
cap production notify_slack           # Deployment completion notification
```

## Instance Deployability

Instances must be "running" and not have a "Deployable" tag set to "false".

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/ec2_deployment_selector.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
