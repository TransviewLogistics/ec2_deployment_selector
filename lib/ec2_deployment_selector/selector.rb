require_relative "wrappers/ec2_instance"

require "aws-sdk-ec2"
require "terminal-table"
require "colorize"

module Ec2DeploymentSelector
  class Selector
    APPLICATION_TAG_KEY = "Application"
    DEFAULT_REGIONS = ["us-west-2", "us-east-2"]

    attr_accessor :selected_instances, :instances
    attr_reader :deployment_metadata

    def initialize(access_key_id:, secret_access_key:, application_name:, regions: DEFAULT_REGIONS, filters: {}, track_metadata: false)
      self.access_key_id = access_key_id
      self.secret_access_key = secret_access_key
      self.application_name = application_name
      self.regions = regions
      self.filters = filters
      @track_metadata = track_metadata
      @deployment_metadata = {} if @track_metadata

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
      selected_instances.map(&:public_ip_address)
    end

    def collect_deployment_metadata
      return nil unless @track_metadata

      update_deployment_metadata
      @deployment_metadata
    end

    def deployment_data_for_notifications
      return {} unless @track_metadata && @deployment_metadata

      {
        application: @deployment_metadata[:application],
        environment: @deployment_metadata[:environment],
        servers: @deployment_metadata[:servers],
        target_ips: @deployment_metadata[:target_ips],
        timestamp: @deployment_metadata[:timestamp],
        regions: @deployment_metadata[:regions],
        instance_count: @deployment_metadata[:instance_count]
      }
    end

    def send_slack_notification(notifier_or_options = {})
      unless metadata_collected?
        puts "⚠️  Cannot send notification: metadata tracking not enabled"
        return false
      end

      notifier = case notifier_or_options
      when Hash
        SlackNotifier.new(**notifier_or_options)
      else
        notifier_or_options
      end

      if notifier.respond_to?(:send_deployment_notification)
        notifier.send_deployment_notification(deployment_data_for_notifications)
      else
        puts "⚠️  Invalid notifier object provided"
        false
      end
    rescue NameError
      puts "⚠️  SlackNotifier not available. Make sure to require the notification module."
      false
    end

    private
    attr_accessor :access_key_id, :secret_access_key, :application_name, :regions, :filters

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
      update_deployment_metadata if @track_metadata
    end

    def update_deployment_metadata
      return unless @track_metadata

      @deployment_metadata.merge!({
        application: application_name,
        environment: detect_environment,
        servers: format_servers_for_metadata,
        target_ips: selected_instances_public_ips.join(","),
        timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S UTC"),
        regions: selected_instances.map(&:region).uniq.sort,
        instance_count: selected_instances.length,
        filters_applied: filters
      })
    end

    def detect_environment
      env_indicators = ['ENV_Type', 'Environment', 'env', 'stage']

      env_indicators.each do |indicator|
        env_value = filters[indicator]
        return env_value if env_value
      end

      "unknown"
    end

    def format_servers_for_metadata
      selected_instances.map do |instance|
        {
          name: instance.name,
          public_ip: instance.public_ip_address,
          private_ip: instance.private_ip_address,
          region: instance.region,
          instance_id: instance.instance_id,
          layers: instance.layers
        }
      end
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
