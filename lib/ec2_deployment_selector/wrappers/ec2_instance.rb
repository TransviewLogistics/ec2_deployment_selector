require "colorize"

module Ec2DeploymentSelector
  module Wrappers
    class Ec2Instance
      REGION_DISPLAY_NAMES = {
        "us-east-2a" => "Ohio (us-east-2)",
        "us-west-2b" => "Oregon (us-west-2)",
      }
      CHEF_STATUS_TAG_KEY = "ChefStatus"
      NAME_TAG_KEY = "Name"
      LAYERS_TAG_KEY = "Layers"
      DEPLOYABLE_TAG_KEY = "Deployable"

      attr_accessor :number, :object

      def initialize(instance)
        self.object = instance
      end

      def public_ip_address
        object.public_ip_address
      end

      def private_ip_address
        object.private_ip_address
      end

      def instance_type
        object.instance_type
      end

      def deployable?
        is_running = object.state.name == "running"
        deployable_tag = tag_value(DEPLOYABLE_TAG_KEY)
        is_deployable = deployable_tag.nil? || deployable_tag.empty? || deployable_tag.downcase != "false"

        is_running && is_deployable
      end

      def name
        tag_value(NAME_TAG_KEY)
      end

      def state
        object.state.name == "running" ? object.state.name.colorize(:green) : object.state.name.colorize(:red)
      end

      def layers
        tag_value(LAYERS_TAG_KEY)
      end

      def region
        REGION_DISPLAY_NAMES[object.placement.availability_zone.chomp] || "Mapping missing (#{object.placement.availability_zone})"
      end

      def chef_status
        if chef_status_value.downcase == "online"
          chef_status_value&.colorize(:green)
        else
          chef_status_value&.colorize(:red)
        end
      end

      def chef_status_value
        @chef_status ||= tag_value(CHEF_STATUS_TAG_KEY) || "unknown"
      end

      def tag_value(key)
        object.tags.detect { |tag| tag.key == key }&.value
      end
    end
  end
end
