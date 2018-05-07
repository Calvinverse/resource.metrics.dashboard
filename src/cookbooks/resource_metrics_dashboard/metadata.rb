# frozen_string_literal: true

chef_version '>= 12.5' if respond_to?(:chef_version)
description 'Environment cookbook that configures a Linux server as a grafana server'
issues_url '${ProductUrl}/issues' if respond_to?(:issues_url)
license 'Apache-2.0'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
name 'resource_metrics_dashboard'
maintainer '${CompanyName} (${CompanyUrl})'
maintainer_email '${EmailDocumentation}'
source_url '${ProductUrl}' if respond_to?(:source_url)
version '${VersionSemantic}'

supports 'ubuntu', '>= 16.04'

depends 'erlang', '= 5.1.0'
depends 'firewall', '= 2.6.2'
depends 'grafana', '= 2.2.1'
depends 'systemd', '= 2.1.3'
