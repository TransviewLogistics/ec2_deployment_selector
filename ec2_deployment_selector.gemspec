lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ec2_deployment_selector/version'

Gem::Specification.new do |spec|
  spec.name          = "ec2_deployment_selector"
  spec.version       = Ec2DeploymentSelector::VERSION
  spec.authors       = ["Calvin Delamere"]
  spec.email         = ["calvin@headlightsolutions.com"]

  spec.summary       = "EC2 deployment server selection and Slack notifications"
  spec.description   = "Selects EC2 instances for deployment and provides Slack notification capabilities."
  # spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.6.0")

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  # spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk-ec2"
  spec.add_dependency "colorize" # Color terminal output
  spec.add_dependency "terminal-table" # Creating tables in terminal output

  spec.add_development_dependency "byebug"
  spec.add_development_dependency "rspec", "~> 3.0"
end
