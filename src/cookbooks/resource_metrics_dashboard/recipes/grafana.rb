# frozen_string_literal: true

#
# Cookbook Name:: resource_metrics_dashboard
# Recipe:: grafana
#
# Copyright 2018, P. van der Velde
#

#
# INSTALL GRAFANA
#

include_recipe 'grafana::default'

#
# DIRECTORIES
#

grafana_provisioning_directory = node['grafana']['provisioning_dir']
directory grafana_provisioning_directory do
  action :create
  group node['grafana']['group']
  mode '775'
  owner node['grafana']['user']
  recursive true
end

grafana_provisioning_datasources_directory = "#{grafana_provisioning_directory}/datasources"
directory grafana_provisioning_datasources_directory do
  action :create
  group node['grafana']['group']
  mode '775'
  owner node['grafana']['user']
  recursive true
end

grafana_provisioning_dashboards_directory = "#{grafana_provisioning_directory}/dashboards"
directory grafana_provisioning_dashboards_directory do
  action :create
  group node['grafana']['group']
  mode '775'
  owner node['grafana']['user']
  recursive true
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
          "enableTagOverride": false,
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

grafana_service = 'grafana-server'

telegraf_graphite_host = '127.0.0.1'
telegraf_graphite_port = '2003'

grafana_config_directory = node['grafana']['conf_dir']
grafana_ldap_config_file = "#{grafana_config_directory}/ldap.toml"

grafana_ini_template_file = node['grafana']['consul_template']['ini']
file "#{consul_template_template_path}/#{grafana_ini_template_file}" do
  action :create
  content <<~CONF
    ##################### Grafana Configuration Example #####################
    #
    # Everything has defaults so you only need to uncomment things you want to
    # change

    # possible values : production, development
    app_mode = production

    # instance name, defaults to HOSTNAME environment variable value or hostname if HOSTNAME var is empty
    instance_name = ${HOSTNAME}

    #################################### Paths ####################################
    [paths]
    # Path to where grafana can store temp files, sessions, and the sqlite3 db (if that is used)
    ;data = /var/lib/grafana

    # Directory where grafana can store logs
    ;logs = /var/log/grafana

    # Directory where grafana will automatically scan and look for plugins
    ;plugins = /var/lib/grafana/plugins

    # folder that contains provisioning config files that grafana will apply on startup and while running.
    provisioning = #{grafana_provisioning_directory}

    #################################### Server ####################################
    [server]
    # Protocol (http, https, socket)
    ;protocol = http

    # The ip address to bind to, empty will bind to all interfaces
    ;http_addr =

    # The http port  to use
    http_port = #{grafana_http_port}

    # The public facing domain name used to access grafana from a browser
    ;domain = localhost

    # Redirect to correct domain if host header does not match domain
    # Prevents DNS rebinding attacks
    ;enforce_domain = false

    # The full public facing url you use in browser, used for redirects and emails
    # If you use reverse proxy and sub path specify full url (with sub path)
    root_url = %(protocol)s://%(domain)s:%(http_port)s/#{proxy_path}

    # Log web requests
    ;router_logging = false

    # the path relative working path
    ;static_root_path = public

    # enable gzip
    ;enable_gzip = false

    # https certs & key file
    ;cert_file =
    ;cert_key =

    # Unix socket path
    ;socket =

    #################################### Database ####################################
    [database]
    # You can configure the database connection by specifying type, host, name, user and password
    # as seperate properties or as on string using the url propertie.

    # Either "mysql", "postgres" or "sqlite3", it's your choice
    ;type = sqlite3
    ;host = 127.0.0.1:3306
    ;name = grafana
    ;user = root
    # If the password contains # or ; you have to wrap it with triple quotes. Ex """#password;"""
    ;password =

    # Use either URL or the previous fields to configure the database
    # Example: mysql://user:secret@host:port/database
    ;url =

    # For "postgres" only, either "disable", "require" or "verify-full"
    ;ssl_mode = disable

    # For "sqlite3" only, path relative to data_path setting
    ;path = grafana.db

    # Max idle conn setting default is 2
    ;max_idle_conn = 2

    # Max conn setting default is 0 (mean not set)
    ;max_open_conn =

    # Connection Max Lifetime default is 14400 (means 14400 seconds or 4 hours)
    ;conn_max_lifetime = 14400

    # Set to true to log the sql calls and execution times.
    log_queries =

    #################################### Session ####################################
    [session]
    # Either "memory", "file", "redis", "mysql", "postgres", default is "file"
    ;provider = file

    # Provider config options
    # memory: not have any config yet
    # file: session dir path, is relative to grafana data_path
    # redis: config like redis server e.g. `addr=127.0.0.1:6379,pool_size=100,db=grafana`
    # mysql: go-sql-driver/mysql dsn config string, e.g. `user:password@tcp(127.0.0.1:3306)/database_name`
    # postgres: user=a password=b host=localhost port=5432 dbname=c sslmode=disable
    ;provider_config = sessions

    # Session cookie name
    ;cookie_name = grafana_sess

    # If you use session in https only, default is false
    ;cookie_secure = false

    # Session life time, default is 86400
    ;session_life_time = 86400

    #################################### Data proxy ###########################
    [dataproxy]

    # This enables data proxy logging, default is false
    ;logging = false


    #################################### Analytics ####################################
    [analytics]
    # Server reporting, sends usage counters to stats.grafana.org every 24 hours.
    # No ip addresses are being tracked, only simple counters to track
    # running instances, dashboard and error counts. It is very helpful to us.
    # Change this option to false to disable reporting.
    reporting_enabled = false

    # Set to false to disable all checks to https://grafana.net
    # for new vesions (grafana itself and plugins), check is used
    # in some UI views to notify that grafana or plugin update exists
    # This option does not cause any auto updates, nor send any information
    # only a GET request to http://grafana.com to get latest versions
    ;check_for_updates = true

    # Google Analytics universal tracking code, only enabled if you specify an id here
    ;google_analytics_ua_id =

    #################################### Security ####################################
    [security]
    # default admin user, created on startup
    ;admin_user = admin

    # default admin password, can be changed before first start of grafana,  or in profile settings
    ;admin_password = admin

    # used for signing
    ;secret_key = SW2YcwTIb9zpOOhoPsMm

    # Auto-login remember days
    ;login_remember_days = 7
    ;cookie_username = grafana_user
    ;cookie_remember_name = grafana_remember

    # disable gravatar profile images
    ;disable_gravatar = false

    # data source proxy whitelist (ip_or_domain:port separated by spaces)
    ;data_source_proxy_whitelist =

    # disable protection against brute force login attempts
    ;disable_brute_force_login_protection = false

    #################################### Snapshots ###########################
    [snapshots]
    # snapshot sharing options
    ;external_enabled = true
    ;external_snapshot_url = https://snapshots-origin.raintank.io
    ;external_snapshot_name = Publish to snapshot.raintank.io

    # remove expired snapshot
    ;snapshot_remove_expired = true

    #################################### Dashboards History ##################
    [dashboards]
    # Number dashboard versions to keep (per dashboard). Default: 20, Minimum: 1
    ;versions_to_keep = 20

    #################################### Users ###############################
    [users]
    # disable user signup / registration
    ;allow_sign_up = true

    # Allow non admin users to create organizations
    allow_org_create = false

    # Set to true to automatically assign new users to the default organization (id 1)
    auto_assign_org = true

    # Default role new users will be automatically assigned (if disabled above is set to true)
    auto_assign_org_role = Viewer

    # Background text for the user field on the login page
    ;login_hint = email or username

    # Default UI theme ("dark" or "light")
    ;default_theme = dark

    # External user management, these options affect the organization users view
    ;external_manage_link_url =
    ;external_manage_link_name =
    ;external_manage_info =

    # Viewers can edit/inspect dashboard settings in the browser. But not save the dashboard.
    ;viewers_can_edit = false

    [auth]
    # Set to true to disable (hide) the login form, useful if you use OAuth, defaults to false
    ;disable_login_form = false

    # Set to true to disable the signout link in the side menu. useful if you use auth.proxy, defaults to false
    ;disable_signout_menu = false

    #################################### Anonymous Auth ##########################
    [auth.anonymous]
    # enable anonymous access
    ;enabled = false

    # specify organization name that should be used for unauthenticated users
    ;org_name = Main Org.

    # specify role for unauthenticated users
    ;org_role = Viewer

    #################################### Github Auth ##########################
    [auth.github]
    enabled = false

    #################################### Google Auth ##########################
    [auth.google]
    enabled = false

    #################################### Generic OAuth ##########################
    [auth.generic_oauth]
    enabled = false

    #################################### Grafana.com Auth ####################
    [auth.grafana_com]
    enabled = false

    #################################### Auth Proxy ##########################
    [auth.proxy]
    enabled = false

    #################################### Basic Auth ##########################
    [auth.basic]
    enabled = false

    #################################### Auth LDAP ##########################
    [auth.ldap]
    enabled = true
    config_file = #{grafana_ldap_config_file}
    allow_sign_up = true

    #################################### SMTP / Emailing ##########################
    [smtp]
    enabled = true
    host = {{ key "config/environment/mail/smtp/host" }}
    ;user =
    # If the password contains # or ; you have to wrap it with trippel quotes. Ex """#password;"""
    ;password =
    ;cert_file =
    ;key_file =
    ;skip_verify = false

    from_address = grafana@{{ key "config/environment/mail/suffix" }}
    from_name = Grafana

    # EHLO identity in SMTP dialog (defaults to instance_name)
    ;ehlo_identity = dashboard.example.com

    [emails]
    ;welcome_email_on_sign_up = false

    #################################### Logging ##########################
    [log]
    # Either "console", "file", "syslog". Default is console and  file
    # Use space to separate multiple modes, e.g. "console file"
    mode = syslog

    # Either "debug", "info", "warn", "error", "critical", default is "info"
    ;level = info

    # optional settings to set different levels for specific loggers. Ex filters = sqlstore:debug
    ;filters =

    # Syslog network type and address. This can be udp, tcp, or unix. If left blank, the default unix endpoints will be used.
    ;network =
    ;address =

    # Syslog facility. user, daemon and local0 through local7 are valid.
    ;facility =

    # Syslog tag. By default, the process' argv[0] is used.
    ;tag =


    #################################### Alerting ############################
    [alerting]
    # Disable alerting engine & UI features
    enabled = true

    # Makes it possible to turn off alert rule execution but alerting UI is visible
    execute_alerts = true

    #################################### Internal Grafana Metrics ##########################
    # Metrics available at HTTP API Url /metrics
    [metrics]
    # Disable / Enable internal metrics
    enabled = true

    # Publish interval
    interval_seconds  = 10

    # Send internal metrics to Graphite
    [metrics.graphite]
    # Enable by setting the address setting (ex localhost:2003)
    address = tcp://#{telegraf_graphite_host}:#{telegraf_graphite_port}
    ;prefix = prod.grafana.%(instance_name)s.

    #################################### Distributed tracing ############
    [tracing.jaeger]
    # Enable by setting the address sending traces to jaeger (ex localhost:6831)
    ;address = localhost:6831
    # Tag that will always be included in when creating new spans. ex (tag1:value1,tag2:value2)
    ;always_included_tag = tag1:value1
    # Type specifies the type of the sampler: const, probabilistic, rateLimiting, or remote
    ;sampler_type = const
    # jaeger samplerconfig param
    # for "const" sampler, 0 or 1 for always false/true respectively
    # for "probabilistic" sampler, a probability between 0 and 1
    # for "rateLimiting" sampler, the number of spans per second
    # for "remote" sampler, param is the same as for "probabilistic"
    # and indicates the initial sampling rate before the actual one
    # is received from the mothership
    ;sampler_param = 1

    #################################### Grafana.com integration  ##########################
    # Url used to to import dashboards directly from Grafana.com
    [grafana_com]
    ;url = https://grafana.com

    #################################### External image storage ##########################
    [external_image_storage]
    # Used for uploading images to public servers so they can be included in slack/email messages.
    # you can choose between (s3, webdav, gcs, azure_blob, local)
    ;provider =

    [external_image_storage.s3]
    ;bucket =
    ;region =
    ;path =
    ;access_key =
    ;secret_key =

    [external_image_storage.webdav]
    ;url =
    ;public_url =
    ;username =
    ;password =

    [external_image_storage.gcs]
    ;key_file =
    ;bucket =
    ;path =

    [external_image_storage.azure_blob]
    ;account_name =
    ;account_key =
    ;container_name =

    [external_image_storage.local]
    # does not require any configuration
  CONF
  mode '755'
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
      destination = "#{grafana_config_directory}/grafana.ini"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "systemctl restart #{grafana_service}"

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
      perms = 0755

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
  mode '755'
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
    bind_password = {{ with secret "secret/environment/directory/users/bind" }}{{ if .Data.password }}"{{ .Data.password }}"{{ end }}{{ end }})

    # User search filter, for example "(cn=%s)" or "(sAMAccountName=%s)" or "(uid=%s)"
    search_filter = "{{ key "config/environment/directory/filter/users/getuser" }}"

    # An array of base dns to search through
    search_base_dns = ["{{ key "config/environment/directory/query/lookupbase" }}"]

    # In POSIX LDAP schemas, without memberOf attribute a secondary query must be made for groups.
    # This is done by enabling group_search_filter below. You must also set member_of= "cn"
    # in [servers.attributes] below.

    ## Group search filter, to retrieve the groups of which the user is a member (only set if memberOf attribute is not available)
    # group_search_filter = "(&(objectClass=posixGroup)(memberUid=%s))"
    ## An array of the base DNs to search through for groups. Typically uses ou=groups
    group_search_base_dns = ["{{ key "config/environment/directory/query/groups/lookupbase" }}"]

    # Specify names of the ldap attributes your ldap uses
    [servers.attributes]
    name = "givenName"
    surname = "sn"
    username = "cn"
    member_of = "memberOf"
    email =  "email"

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
  mode '755'
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
      command = "systemctl restart #{grafana_service}"

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
      perms = 0755

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
  mode '755'
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

    if ( ! (systemctl is-active --quiet #{grafana_service}) ); then
      systemctl restart #{grafana_service}
    fi
  CONF
  mode '755'
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
      perms = 0755

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
  mode '755'
end

grafana_provisioning_dashboards_script_template_file = node['grafana']['consul_template']['provisioning_dashboards_script']
file "#{consul_template_template_path}/#{grafana_provisioning_dashboards_script_template_file}" do
  action :create
  content <<~CONF
    #!/bin/sh

    {{ range ls "config/services/dashboards/metrics/provisioning/dashboards" }}
    cat <<EOT > #{grafana_provisioning_dashboards_directory}/{{ .Key }}.yaml
    {{ .Value }}
    EOT
    {{ end }}

    if ( ! (systemctl is-active --quiet #{grafana_service}) ); then
      systemctl restart #{grafana_service}
    fi
  CONF
  mode '755'
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
      perms = 0755

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
  mode '755'
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
  mode '755'
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
      command = "systemctl reload #{telegraf_service}"

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
      perms = 0755

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
  mode '755'
end
