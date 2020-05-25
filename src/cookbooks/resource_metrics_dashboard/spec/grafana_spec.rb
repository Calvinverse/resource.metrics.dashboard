# frozen_string_literal: true

require 'spec_helper'

describe 'resource_metrics_dashboard::grafana' do
  context 'installs Grafana' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs grafana' do
      expect(chef_run).to install_grafana_install('grafana')
    end
  end

  context 'creates the provisioning directories' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates the provisioning directory at /etc/grafana/provisioning' do
      expect(chef_run).to create_directory('/etc/grafana/provisioning').with(
        group: 'grafana',
        mode: '750',
        owner: 'grafana'
      )
    end

    it 'creates the datasources provisioning directory at /etc/grafana/provisioning/datasources' do
      expect(chef_run).to create_directory('/etc/grafana/provisioning/datasources').with(
        group: 'grafana',
        mode: '750',
        owner: 'grafana'
      )
    end

    it 'creates the dashboards provisioning directory at /etc/grafana/provisioning/dashboards' do
      expect(chef_run).to create_directory('/etc/grafana/provisioning/dashboards').with(
        group: 'grafana',
        mode: '750',
        owner: 'grafana'
      )
    end

    it 'creates the dashboards files directory at /etc/grafana/dashboards' do
      expect(chef_run).to create_directory('/etc/grafana/dashboards').with(
        group: 'grafana',
        mode: '750',
        owner: 'grafana'
      )
    end
  end

  context 'configures the firewall for Grafana' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the Grafana HTTP port' do
      expect(chef_run).to create_firewall_rule('grafana-http').with(
        command: :allow,
        dest_port: 3000,
        direction: :in
      )
    end
  end

  context 'registers the service with consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_grafana_http_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "http": "http://localhost:3000/api/health",
                "id": "grafana_http_health_check",
                "interval": "30s",
                "method": "GET",
                "name": "Grafana HTTP health check",
                "timeout": "5s"
              }
            ],
            "enable_tag_override": false,
            "id": "grafana_http",
            "name": "metrics",
            "port": 3000,
            "tags": [
              "dashboard",
              "edgeproxyprefix-/dashboards/metrics strip=/dashboards/metrics"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/grafana-http.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/grafana-http.json')
        .with_content(consul_grafana_http_config_content)
    end
  end

  context 'adds the consul-template files for grafana' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates grafana ini template file in the consul-template template directory' do
      expect(chef_run).to create_template('/etc/consul-template.d/templates/grafana_custom_ini.ctmpl')
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550',
          source: 'grafana_ini.erb'
        )
    end

    consul_template_grafana_ini_inputs_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/grafana_custom_ini.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/etc/grafana/grafana.ini"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "/bin/bash -c 'chown grafana:grafana /etc/grafana/grafana.ini && systemctl restart grafana-server'"

        # This is the maximum amount of time to wait for the optional command to
        # return. Default is 30s.
        command_timeout = "15s"

        # Exit with an error when accessing a struct or map field/key that does not
        # exist. The default behavior will print "<no value>" when accessing a field
        # that does not exist. It is highly recommended you set this to "true" when
        # retrieving secrets from Vault.
        error_on_missing_key = false

        # This is the permission to render the file. If this option is left
        # unspecified, Consul Template will attempt to match the permissions of the
        # file that already exists at the destination path. If no file exists at that
        # path, the permissions are 0644.
        perms = 0550

        # This option backs up the previously rendered template at the destination
        # path before writing a new one. It keeps exactly one backup. This option is
        # useful for preventing accidental changes to the data without having a
        # rollback strategy.
        backup = true

        # These are the delimiters to use in the template. The default is "{{" and
        # "}}", but for some templates, it may be easier to use a different delimiter
        # that does not conflict with the output file itself.
        left_delimiter  = "{{"
        right_delimiter = "}}"

        # This is the `minimum(:maximum)` to wait before rendering a new template to
        # disk and triggering a command, separated by a colon (`:`). If the optional
        # maximum value is omitted, it is assumed to be 4x the required minimum value.
        # This is a numeric time with a unit suffix ("5s"). There is no default value.
        # The wait value for a template takes precedence over any globally-configured
        # wait.
        wait {
          min = "2s"
          max = "10s"
        }
      }
    CONF
    it 'creates telegraf_grafana_inputs.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/grafana_custom_ini.hcl')
        .with_content(consul_template_grafana_ini_inputs_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    grafana_ldap_template_content = <<~CONF
      # Set to true to log user information returned from LDAP
      verbose_logging = false

      [[servers]]
      # Ldap server host (specify multiple hosts space separated)
      host = "{{ range ls "config/environment/directory/endpoints/hosts" }}{{ .Value }} {{ end }}"

      # Default port is 389 or 636 if use_ssl = true
      port = 389

      # Set to true if ldap server supports TLS
      use_ssl = false

      # Set to true if connect ldap server with STARTTLS pattern (create connection in insecure, then upgrade to secure connection with TLS)
      start_tls = false

      # set to true if you want to skip ssl cert validation
      ssl_skip_verify = false

      # set to the path to your root CA certificate or leave unset to use system defaults
      # root_ca_cert = "/path/to/certificate.crt"

      # Search user bind dn
      bind_dn = "{{ key "config/environment/directory/users/bindcn" }}"

      # Search user bind password
      # If the password contains # or ; you have to wrap it with triple quotes. Ex """#password;"""
      bind_password = """{{ with secret "secret/environment/directory/users/bind" }}{{ if .Data.password }}{{ .Data.password }}{{ end }}{{ end }}"""

      # User search filter, for example "(cn=%s)" or "(sAMAccountName=%s)" or "(uid=%s)"
      search_filter = "(sAMAccountName=%s)"

      # An array of base dns to search through
      search_base_dns = ["{{ key "config/environment/directory/query/lookupbase" }}"]

      # In POSIX LDAP schemas, without memberOf attribute a secondary query must be made for groups.
      # This is done by enabling group_search_filter below. You must also set member_of= "cn"
      # in [servers.attributes] below.

      ## Group search filter, to retrieve the groups of which the user is a member (only set if memberOf attribute is not available)
      group_search_filter = "(member:1.2.840.113556.1.4.1941:=%s)"
      group_search_filter_user_attribute = "distinguishedName"
      ## An array of the base DNs to search through for groups. Typically uses ou=groups
      group_search_base_dns = ["{{ key "config/environment/directory/query/groups/lookupbase" }}"]

      # Specify names of the ldap attributes your ldap uses
      [servers.attributes]
      name = "givenName"
      surname = "sn"
      username = "sAMAccountName"
      member_of = "distinguishedName"
      email =  "mail"

      # Map ldap groups to grafana org roles
      [[servers.group_mappings]]
      group_dn = "{{ key "config/environment/directory/query/groups/queue/administrators" }}"
      org_role = "Admin"
      # The Grafana organization database id, optional, if left out the default org (id 1) will be used.  Setting this allows for multiple group_dn's to be assigned to the same org_role provided the org_id differs
      # org_id = 1

      # [[servers.group_mappings]]
      # group_dn = "cn=users,dc=grafana,dc=org"
      # org_role = "Editor"

      [[servers.group_mappings]]
      # If you want to match all (or no ldap groups) then you can use wildcard
      group_dn = "*"
      org_role = "Viewer"
    CONF
    it 'creates grafana ldap template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/grafana_ldap.ctmpl')
        .with_content(grafana_ldap_template_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    consul_template_grafana_ldap_inputs_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/grafana_ldap.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/etc/grafana/ldap.toml"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "/bin/bash -c 'chown grafana:grafana /etc/grafana/ldap.toml && systemctl restart grafana-server'"

        # This is the maximum amount of time to wait for the optional command to
        # return. Default is 30s.
        command_timeout = "15s"

        # Exit with an error when accessing a struct or map field/key that does not
        # exist. The default behavior will print "<no value>" when accessing a field
        # that does not exist. It is highly recommended you set this to "true" when
        # retrieving secrets from Vault.
        error_on_missing_key = false

        # This is the permission to render the file. If this option is left
        # unspecified, Consul Template will attempt to match the permissions of the
        # file that already exists at the destination path. If no file exists at that
        # path, the permissions are 0644.
        perms = 0550

        # This option backs up the previously rendered template at the destination
        # path before writing a new one. It keeps exactly one backup. This option is
        # useful for preventing accidental changes to the data without having a
        # rollback strategy.
        backup = true

        # These are the delimiters to use in the template. The default is "{{" and
        # "}}", but for some templates, it may be easier to use a different delimiter
        # that does not conflict with the output file itself.
        left_delimiter  = "{{"
        right_delimiter = "}}"

        # This is the `minimum(:maximum)` to wait before rendering a new template to
        # disk and triggering a command, separated by a colon (`:`). If the optional
        # maximum value is omitted, it is assumed to be 4x the required minimum value.
        # This is a numeric time with a unit suffix ("5s"). There is no default value.
        # The wait value for a template takes precedence over any globally-configured
        # wait.
        wait {
          min = "2s"
          max = "10s"
        }
      }
    CONF
    it 'creates grafana_ldap.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/grafana_ldap.hcl')
        .with_content(consul_template_grafana_ldap_inputs_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    grafana_provisioning_datasources_script_template_content = <<~CONF
      #!/bin/sh

      {{ range ls "config/services/dashboards/metrics/provisioning/datasources" }}
      cat <<EOT > /etc/grafana/provisioning/datasources/{{ .Key }}.yaml
      {{ .Value }}
      EOT
      {{ end }}

      systemctl restart grafana-server
    CONF
    it 'creates grafana datasources provisioning script template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/grafana_datasources.ctmpl')
        .with_content(grafana_provisioning_datasources_script_template_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    consul_template_grafana_provisioning_datasources_inputs_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/grafana_datasources.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/tmp/grafana_datasources.sh"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "sh /tmp/grafana_datasources.sh"

        # This is the maximum amount of time to wait for the optional command to
        # return. Default is 30s.
        command_timeout = "15s"

        # Exit with an error when accessing a struct or map field/key that does not
        # exist. The default behavior will print "<no value>" when accessing a field
        # that does not exist. It is highly recommended you set this to "true" when
        # retrieving secrets from Vault.
        error_on_missing_key = false

        # This is the permission to render the file. If this option is left
        # unspecified, Consul Template will attempt to match the permissions of the
        # file that already exists at the destination path. If no file exists at that
        # path, the permissions are 0644.
        perms = 0550

        # This option backs up the previously rendered template at the destination
        # path before writing a new one. It keeps exactly one backup. This option is
        # useful for preventing accidental changes to the data without having a
        # rollback strategy.
        backup = true

        # These are the delimiters to use in the template. The default is "{{" and
        # "}}", but for some templates, it may be easier to use a different delimiter
        # that does not conflict with the output file itself.
        left_delimiter  = "{{"
        right_delimiter = "}}"

        # This is the `minimum(:maximum)` to wait before rendering a new template to
        # disk and triggering a command, separated by a colon (`:`). If the optional
        # maximum value is omitted, it is assumed to be 4x the required minimum value.
        # This is a numeric time with a unit suffix ("5s"). There is no default value.
        # The wait value for a template takes precedence over any globally-configured
        # wait.
        wait {
          min = "2s"
          max = "10s"
        }
      }
    CONF
    it 'creates grafana_provisioning_datasources.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/grafana_provisioning_datasources.hcl')
        .with_content(consul_template_grafana_provisioning_datasources_inputs_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    grafana_provisioning_dashboards_script_template_content = <<~CONF
      #!/bin/sh

      cat <<'EOT' > /etc/grafana/provisioning/dashboards/dashboards.yaml
      apiVersion: 1

      providers:
      EOT

      {{ range $key, $pairs := tree "config/services/dashboards/metrics/provisioning/dashboards" | byKey }}

      cat <<'EOT' >> /etc/grafana/provisioning/dashboards/dashboards.yaml
      - name: '{{ $key }}'
        orgId: 1
        folder: '{{ $key }}'
        type: file
        disableDeletion: false
        options:
          path: /etc/grafana/dashboards/{{ $key }}
      EOT

      mkdir -p /etc/grafana/dashboards/{{ $key }}

      {{ range $pair := $pairs }}
      cat <<'EOT' > /etc/grafana/dashboards/{{ $key }}/{{ .Key }}.json
      {{ .Value }}
      EOT
      {{ end }}{{ end }}

      systemctl restart grafana-server
    CONF
    it 'creates grafana dashboards provisioning script template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/grafana_dashboards.ctmpl')
        .with_content(grafana_provisioning_dashboards_script_template_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    consul_template_grafana_provisioning_dashboards_inputs_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/grafana_dashboards.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/tmp/grafana_dashboards.sh"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "sh /tmp/grafana_dashboards.sh"

        # This is the maximum amount of time to wait for the optional command to
        # return. Default is 30s.
        command_timeout = "15s"

        # Exit with an error when accessing a struct or map field/key that does not
        # exist. The default behavior will print "<no value>" when accessing a field
        # that does not exist. It is highly recommended you set this to "true" when
        # retrieving secrets from Vault.
        error_on_missing_key = false

        # This is the permission to render the file. If this option is left
        # unspecified, Consul Template will attempt to match the permissions of the
        # file that already exists at the destination path. If no file exists at that
        # path, the permissions are 0644.
        perms = 0550

        # This option backs up the previously rendered template at the destination
        # path before writing a new one. It keeps exactly one backup. This option is
        # useful for preventing accidental changes to the data without having a
        # rollback strategy.
        backup = true

        # These are the delimiters to use in the template. The default is "{{" and
        # "}}", but for some templates, it may be easier to use a different delimiter
        # that does not conflict with the output file itself.
        left_delimiter  = "{{"
        right_delimiter = "}}"

        # This is the `minimum(:maximum)` to wait before rendering a new template to
        # disk and triggering a command, separated by a colon (`:`). If the optional
        # maximum value is omitted, it is assumed to be 4x the required minimum value.
        # This is a numeric time with a unit suffix ("5s"). There is no default value.
        # The wait value for a template takes precedence over any globally-configured
        # wait.
        wait {
          min = "2s"
          max = "10s"
        }
      }
    CONF
    it 'creates grafana_provisioning_dashboards.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/grafana_provisioning_dashboards.hcl')
        .with_content(consul_template_grafana_provisioning_dashboards_inputs_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end
  end

  context 'adds the consul-template files for telegraf monitoring of grafana' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    telegraf_grafana_inputs_template_content = <<~CONF
      # Telegraf Configuration

      ###############################################################################
      #                            INPUT PLUGINS                                    #
      ###############################################################################

      # Generic socket listener capable of handling multiple socket types.
      [[inputs.socket_listener]]
        ## URL to listen on
        service_address = "tcp://127.0.0.1:2003"

        ## Maximum number of concurrent connections.
        ## Only applies to stream sockets (e.g. TCP).
        ## 0 (default) is unlimited.
        # max_connections = 1024

        ## Read timeout.
        ## Only applies to stream sockets (e.g. TCP).
        ## 0 (default) is unlimited.
        # read_timeout = "30s"

        ## Maximum socket buffer size in bytes.
        ## For stream sockets, once the buffer fills up, the sender will start backing up.
        ## For datagram sockets, once the buffer fills up, metrics will start dropping.
        ## Defaults to the OS default.
        # read_buffer_size = 65535

        ## Period between keep alive probes.
        ## Only applies to TCP sockets.
        ## 0 disables keep alive probes.
        ## Defaults to the OS configuration.
        # keep_alive_period = "5m"

        ## Data format to consume.
        ## Each data format has its own unique set of configuration options, read
        ## more about them here:
        ## https://github.com/influxdata/telegraf/blob/master/docs/DATA_FORMATS_INPUT.md
        data_format = "graphite"
        [inputs.socket_listener.tags]
          influxdb_database = "{{ keyOrDefault "config/services/metrics/databases/services" "services" }}"
    CONF
    it 'creates telegraf grafana input template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/telegraf_grafana_inputs.ctmpl')
        .with_content(telegraf_grafana_inputs_template_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end

    consul_template_telegraf_grafana_inputs_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/telegraf_grafana_inputs.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/etc/telegraf/telegraf.d/inputs_grafana.conf"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "/bin/bash -c 'chown telegraf:telegraf /etc/telegraf/telegraf.d/inputs_grafana.conf && systemctl restart telegraf'"

        # This is the maximum amount of time to wait for the optional command to
        # return. Default is 30s.
        command_timeout = "15s"

        # Exit with an error when accessing a struct or map field/key that does not
        # exist. The default behavior will print "<no value>" when accessing a field
        # that does not exist. It is highly recommended you set this to "true" when
        # retrieving secrets from Vault.
        error_on_missing_key = false

        # This is the permission to render the file. If this option is left
        # unspecified, Consul Template will attempt to match the permissions of the
        # file that already exists at the destination path. If no file exists at that
        # path, the permissions are 0644.
        perms = 0550

        # This option backs up the previously rendered template at the destination
        # path before writing a new one. It keeps exactly one backup. This option is
        # useful for preventing accidental changes to the data without having a
        # rollback strategy.
        backup = true

        # These are the delimiters to use in the template. The default is "{{" and
        # "}}", but for some templates, it may be easier to use a different delimiter
        # that does not conflict with the output file itself.
        left_delimiter  = "{{"
        right_delimiter = "}}"

        # This is the `minimum(:maximum)` to wait before rendering a new template to
        # disk and triggering a command, separated by a colon (`:`). If the optional
        # maximum value is omitted, it is assumed to be 4x the required minimum value.
        # This is a numeric time with a unit suffix ("5s"). There is no default value.
        # The wait value for a template takes precedence over any globally-configured
        # wait.
        wait {
          min = "2s"
          max = "10s"
        }
      }
    CONF
    it 'creates telegraf_grafana_inputs.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/telegraf_grafana_inputs.hcl')
        .with_content(consul_template_telegraf_grafana_inputs_content)
        .with(
          group: 'root',
          owner: 'root',
          mode: '0550'
        )
    end
  end
end
