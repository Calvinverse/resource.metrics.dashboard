# frozen_string_literal: true

#
# Cookbook Name:: resource_metrics_dashboard
# Recipe:: grafana
#
# Copyright 2018, P. van der Velde
#

group node['grafana']['service_group'] do
  action :create
  system true
end

user node['grafana']['service_user'] do
  action :create
  gid node['grafana']['service_group']
  shell '/bin/false'
  system true
end

#
# INSTALL GRAFANA
#

grafana_install 'grafana' do
  action :install
  version node['grafana']['version']
end

#
# DIRECTORIES
#

grafana_config_directory = node['grafana']['path']['config']

grafana_provisioning_directory = node['grafana']['provisioning_dir']
directory grafana_provisioning_directory do
  action :create
  group node['grafana']['service_group']
  mode '750'
  owner node['grafana']['service_user']
  recursive true
end

grafana_provisioning_datasources_directory = "#{grafana_provisioning_directory}/datasources"
directory grafana_provisioning_datasources_directory do
  action :create
  group node['grafana']['service_group']
  mode '750'
  owner node['grafana']['service_user']
  recursive true
end

grafana_provisioning_dashboards_directory = "#{grafana_provisioning_directory}/dashboards"
directory grafana_provisioning_dashboards_directory do
  action :create
  group node['grafana']['service_group']
  mode '750'
  owner node['grafana']['service_user']
  recursive true
end

grafana_provisioning_dashboards_files_directory = node['grafana']['dashboards_dir']
directory grafana_provisioning_dashboards_files_directory do
  action :create
  group node['grafana']['service_group']
  mode '750'
  owner node['grafana']['service_user']
  recursive true
end

#
# SERVICE
#

grafana_config_file = "#{grafana_config_directory}/grafana.ini"

pid_dir = '/tmp'

grafana_environment_directory = '/etc/default'
grafana_environment_file = "#{grafana_environment_directory}/grafana-server"
file grafana_environment_file do
  content <<~TXT
    GRAFANA_USER=#{node['grafana']['service_user']}
    GRAFANA_GROUP=#{node['grafana']['service_group']}
    GRAFANA_HOME=/usr/share/grafana
    LOG_DIR=/var/log/grafana
    DATA_DIR=/var/lib/grafana
    PLUGINS_DIR=/var/lib/grafana/plugins
    MAX_OPEN_FILES=10000
    CONF_DIR=#{grafana_config_directory}
    CONF_FILE=#{grafana_config_file}
    PID_FILE_DIR=#{pid_dir}
    RESTART_ON_UPGRADE=false
  TXT
end

grafana_service = 'grafana-server'
grafana_install_path = '/usr/sbin/grafana-server'

grafana_pid_file = "#{pid_dir}/grafana-server.pid"
systemd_service grafana_service do
  action :create
  install do
    wanted_by %w[multi-user.target]
  end
  service do
    environment_file grafana_environment_file
    exec_start "#{grafana_install_path} --config=#{grafana_config_file} --pidfile=#{grafana_pid_file} --packaging=deb"
    group node['grafana']['service_group']
    pid_file grafana_pid_file
    restart 'on-failure'
    user node['grafana']['service_user']
    working_directory '/usr/share/grafana'
  end
  unit do
    after %w[network-online.target]
    description 'Grafana instance'
    documentation 'http://docs.grafana.org'
    wants %w[network-online.target]
  end
end

service grafana_service do
  action :enable
end

#
# DEFAULT CONFIGURATION
#

# Create a default configuration file for grafana. To be overwritten when consul-template
# is authenticated
grafana_config 'grafana' do
  conf_directory grafana_config_directory
  env_directory grafana_environment_directory
  group node['grafana']['service_group']
  owner node['grafana']['service_user']
  restart_on_upgrade true
end

#
# ALLOW GRAFANA THROUGH THE FIREWALL
#

grafana_http_port = node['grafana']['port']['http']
firewall_rule 'grafana-http' do
  command :allow
  description 'Allow Grafana HTTP traffic'
  dest_port grafana_http_port
  direction :in
end

#
# CONSUL FILES
#

proxy_path = node['grafana']['proxy_path']
file '/etc/consul/conf.d/grafana-http.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "http": "http://localhost:#{grafana_http_port}/api/health",
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
          "port": #{grafana_http_port},
          "tags": [
            "dashboard",
            "edgeproxyprefix-/#{proxy_path} strip=/#{proxy_path}"
          ]
        }
      ]
    }
  JSON
end

#
# CONSUL-TEMPLATE FILES
#

consul_template_config_path = node['consul_template']['config_path']
consul_template_template_path = node['consul_template']['template_path']

telegraf_graphite_host = '127.0.0.1'
telegraf_graphite_port = '2003'

grafana_ldap_config_file = "#{grafana_config_directory}/ldap.toml"

grafana_ini_template_file = node['grafana']['consul_template']['ini']

template "#{consul_template_template_path}/#{grafana_ini_template_file}" do
  action :create
  group 'root'
  mode '0550'
  owner 'root'
  source 'grafana_ini.erb'
  variables(
    provisioning_directory: grafana_provisioning_directory,
    http_port: grafana_http_port,
    proxy_path: proxy_path,
    ldap_config_file: grafana_ldap_config_file,
    graphite_host: telegraf_graphite_host,
    graphite_port: telegraf_graphite_port
  )
end

file "#{consul_template_config_path}/grafana_custom_ini.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{grafana_ini_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{grafana_config_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "/bin/bash -c 'chown #{node['grafana']['service_user']}:#{node['grafana']['service_group']} #{grafana_config_file} && systemctl restart #{grafana_service}'"

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
  HCL
  group 'root'
  mode '0550'
  owner 'root'
end

grafana_ldap_template_file = node['grafana']['consul_template']['ldap']
file "#{consul_template_template_path}/#{grafana_ldap_template_file}" do
  action :create
  content <<~CONF
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
  group 'root'
  mode '0550'
  owner 'root'
end

file "#{consul_template_config_path}/grafana_ldap.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{grafana_ldap_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{grafana_ldap_config_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "/bin/bash -c 'chown #{node['grafana']['service_user']}:#{node['grafana']['service_group']} #{grafana_ldap_config_file} && systemctl restart #{grafana_service}'"

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
  HCL
  group 'root'
  mode '0550'
  owner 'root'
end

grafana_provisioning_datasources_script_template_file = node['grafana']['consul_template']['provisioning_datasources_script']
file "#{consul_template_template_path}/#{grafana_provisioning_datasources_script_template_file}" do
  action :create
  content <<~CONF
    #!/bin/sh

    {{ range ls "config/services/dashboards/metrics/provisioning/datasources" }}
    cat <<EOT > #{grafana_provisioning_datasources_directory}/{{ .Key }}.yaml
    {{ .Value }}
    EOT
    {{ end }}

    systemctl restart #{grafana_service}
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

grafana_provisioning_datasources_script = '/tmp/grafana_datasources.sh'
file "#{consul_template_config_path}/grafana_provisioning_datasources.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{grafana_provisioning_datasources_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{grafana_provisioning_datasources_script}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{grafana_provisioning_datasources_script}"

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
  HCL
  group 'root'
  mode '0550'
  owner 'root'
end

grafana_provisioning_dashboards_script_template_file = node['grafana']['consul_template']['provisioning_dashboards_script']
file "#{consul_template_template_path}/#{grafana_provisioning_dashboards_script_template_file}" do
  action :create
  content <<~CONF
    #!/bin/sh

    cat <<'EOT' > #{grafana_provisioning_dashboards_directory}/dashboards.yaml
    apiVersion: 1

    providers:
    EOT

    {{ range $key, $pairs := tree "config/services/dashboards/metrics/provisioning/dashboards" | byKey }}

    cat <<'EOT' >> #{grafana_provisioning_dashboards_directory}/dashboards.yaml
    - name: '{{ $key }}'
      orgId: 1
      folder: '{{ $key }}'
      type: file
      disableDeletion: false
      options:
        path: #{grafana_provisioning_dashboards_files_directory}/{{ $key }}
    EOT

    mkdir -p #{grafana_provisioning_dashboards_files_directory}/{{ $key }}

    {{ range $pair := $pairs }}
    cat <<'EOT' > #{grafana_provisioning_dashboards_files_directory}/{{ $key }}/{{ .Key }}.json
    {{ .Value }}
    EOT
    {{ end }}{{ end }}

    systemctl restart #{grafana_service}
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

grafana_provisioning_dashboards_script = '/tmp/grafana_dashboards.sh'
file "#{consul_template_config_path}/grafana_provisioning_dashboards.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{grafana_provisioning_dashboards_script_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{grafana_provisioning_dashboards_script}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "sh #{grafana_provisioning_dashboards_script}"

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
  HCL
  group 'root'
  mode '0550'
  owner 'root'
end

telegraf_service = 'telegraf'
telegraf_config_directory = node['telegraf']['config_directory']
telegraf_grafana_inputs_template_file = node['grafana']['telegraf']['consul_template_inputs_file']
file "#{consul_template_template_path}/#{telegraf_grafana_inputs_template_file}" do
  action :create
  content <<~CONF
    # Telegraf Configuration

    ###############################################################################
    #                            INPUT PLUGINS                                    #
    ###############################################################################

    # Generic socket listener capable of handling multiple socket types.
    [[inputs.socket_listener]]
      ## URL to listen on
      service_address = "tcp://#{telegraf_graphite_host}:#{telegraf_graphite_port}"

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
  group 'root'
  mode '0550'
  owner 'root'
end

file "#{consul_template_config_path}/telegraf_grafana_inputs.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{telegraf_grafana_inputs_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{telegraf_config_directory}/inputs_grafana.conf"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "/bin/bash -c 'chown #{node['telegraf']['service_user']}:#{node['telegraf']['service_group']} #{telegraf_config_directory}/inputs_grafana.conf && systemctl restart #{telegraf_service}'"

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
  HCL
  group 'root'
  mode '0550'
  owner 'root'
end
