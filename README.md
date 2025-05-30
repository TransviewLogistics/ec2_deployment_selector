# Ec2DeploymentSelector

EC2 Deployment Selector is a Ruby gem that simplifies the process of selecting Amazon EC2 instances for deployment. It provides an interactive interface for filtering and selecting instances based on tags, regions, and application names. It's particularly useful when integrated with Capistrano for deployment automation.

This gem allows you to:
- Fetch EC2 instances across multiple AWS regions
- Filter instances by application name and custom tags
- Present instances in a formatted table with color-coded status information
- Interactively select instances for deployment
- Support non-interactive mode for CI/CD pipelines

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ec2_deployment_selector'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install ec2_deployment_selector

## Usage

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

## Instance Deployability

Instances must be "running" and not have a "Deployable" tag set to "false".

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/ec2_deployment_selector.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
