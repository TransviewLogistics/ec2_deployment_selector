require_relative "wrappers/ec2_instance"

require "aws-sdk-ec2"
require "terminal-table"
require "colorize"

module Ec2DeploymentSelector
  class Selector
    APPLICATION_TAG_KEY = "Application"
    DEFAULT_REGIONS = ["us-west-2", "us-east-2"]

    attr_accessor :selected_instances, :instances

    def initialize(access_key_id:, secret_access_key:, application_name:, regions: DEFAULT_REGIONS, filters: {})
      self.access_key_id = access_key_id
      self.secret_access_key = secret_access_key
      self.application_name = application_name
      self.regions = regions
      self.filters = filters

      self.instances = fetch_relevant_wrapped_instances
    end

    def render_all_instances
      title = "\u{1F680} Select #{application_name} Instances for Deployment \u{1F680}".colorize(mode: :bold)
      render_table(instances, title, include_num_column: true)
    end

    def confirm_selected_instances
      title = "\u{2753} Confirm Deployment to Instances \u{2753}".colorize(mode: :bold)
      render_table(selected_instances, title, include_num_column: false)

      puts "\u{2705} Press Y to confirm, or any other key to reselect:"
      confirm = ENV["NON_INTERACTIVE"] == "true" ? "y" : STDIN.gets

      if confirm.strip.downcase != "y"
        self.selected_instances = []
        render_all_instances
        prompt_select_instances
        confirm_selected_instances
      end
    end

    def prompt_select_instances
      puts "\u{1F680} Select instances by Num to deploy to (comma separated), or enter for all deployable instances:"

      selected_instance_numbers_input = ENV["NON_INTERACTIVE"] == "true" ? "" : STDIN.gets

      selected_instance_numbers = if selected_instance_numbers_input.strip == ""
        instances.select(&:deployable?).map(&:number)
      else
        selected_instance_numbers_input.split(",").map{ |n| n.strip.to_i }.uniq
      end

      validate_and_set_selected_instances(selected_instance_numbers)
    end

    def selected_instances_public_ips
      auto_register_for_capistrano_notifications
      selected_instances.map(&:public_ip_address)
    end

    private

    attr_accessor :access_key_id, :secret_access_key, :application_name, :regions, :filters

    def auto_register_for_capistrano_notifications
      begin
        require_relative 'slack_notifier'
        Ec2DeploymentSelector::SlackNotifier.register_ec2_instances(selected_instances)
      rescue LoadError, NameError => e
        # Silently ignore if Slack notifier is not available
      end
    end

    def render_table(instances, title, include_num_column:)
      rows = instances.map do |instance|
        row(instance, include_num_column)
      end

      headings = ["Name", "Instance Status", "Layers", "Public IP", "Private IP", "Region", "Deployable"].map { |h| h.colorize(mode: :bold) }
      headings = ["Num"] + headings if include_num_column
      table = Terminal::Table.new(
        title: title,
        headings: headings,
        rows: rows
      )

      puts table
    end

    def row(instance, include_num_column)
      row = [
        instance.name,
        instance.state,
        instance.layers,
        instance.public_ip_address,
        instance.private_ip_address,
        instance.region,
        instance.deployable? ? "Yes" : "No",
      ]
      if include_num_column
        number = instance.deployable? ? instance.number : "-"
        row = [number] + row
      end

      row
    end

    def validate_and_set_selected_instances(selected_instance_numbers)
      self.selected_instances = []
      valid_selected_instances = []

      selected_instance_numbers.each_with_index do |instance_number|
        instance = instances[instance_number.to_i - 1]
        if instance.deployable?
          valid_selected_instances << instance
        else
          self.selected_instances = []
          puts "Instance #{instance_number} is not deployable"
          prompt_select_instances
          break
        end
      end

      self.selected_instances = valid_selected_instances
    end

    def fetch_relevant_wrapped_instances
      instances = fetch_all_instances
      instances = filter_instances(instances)
      wrapped_instances = instances.map { |instance| Wrappers::Ec2Instance.new(instance) }
      wrapped_instances.sort_by! { |instance| instance.deployable? ? 0 : 1 }
      wrapped_instances.each_with_index { |instance, index| instance.number = index + 1 }

      self.instances = wrapped_instances
    end

    def fetch_all_instances
      instances = []
      regions.each do |region|
        client = Aws::EC2::Resource.new(
          access_key_id: access_key_id,
          secret_access_key: secret_access_key,
          region: region
        )

        instances += client.instances.select { |instance| instance.tags.detect { |tag| tag.key == APPLICATION_TAG_KEY && tag.value == application_name } }
      end

      instances
    end

    def filter_instances(instances)
      instances.select do |instance|
        filters.all? do |tag_key, tag_value|
          instance.tags.any? do |tag|
            normalized_tag_key(tag.key) == normalized_tag_key(tag_key) && tag.value == tag_value
          end
        end
      end
    end

    def normalized_tag_key(tag_key)
      tag_key.downcase.gsub(" ", "")
    end
  end
end
