# resource.metrics.dashboard

This repository contains the source code for the Resource-Metrics.Dashboard image, the image that contains an
instance of the [Grafana dashboard application](https://grafana.com/).

## Image

The image is created by using the [Linux base image](https://github.com/Calvinverse/base.linux)
and amending it using a [Chef](https://www.chef.io/chef/) cookbook which installs Grafana.

### Contents

* The Grafana application. The version of which is determined by the
  `default['grafana']['version']` attribute in the `default.rb` attributes file in the cookbook.

### Configuration

The configuration for the Grafana instance comes from a
[Consul-Template](https://github.com/hashicorp/consul-template) template file which replaces some
of the template parameters with values from the Consul Key-Value store.

Important parts of the configuration file are

* Authentication is done via LDAP which is configued to use the Vista Active Directory system.
* Dashboards and data sources are assumed to be obtained from the Consul Key-Value store via
  Consul-Template using the [Grafana provisioning](http://docs.grafana.org/administration/provisioning/)
  feature.
* Metrics are pushed to Telegraf via the Graphite protocol

### Authentication

In order to interact with Grafana users need to be authenticated.

Physical users are authenticated with Active Directory via the LDAP plugin which uses the following
settings.

Setting | Consul Key-Value path | Example
--------|-----------------------|---------
Active directory servers | `config/environment/directory/endpoints/hosts` | ad01.example.com, ad02.example.com
DN lookup attribute | `sAMAccountName` | -
DN lookup base | `/config/environment/directory/query/lookupbase` | `OU=Users,DC=ad,DC=example,DC=com`
Group lookup base | `/config/environment/directory/query/groups/lookupbase` | `OU=Groups,DC=ad,DC=example,DC=com`
Administrator group | `config/environment/directory/query/groups/queue/administrators` | `CN=Metrics Administrators,OU=Groups,DC=ad,DC=example,DC=com`

The initial configuration is provided via Consul-Template by providing Consul-Template with the
authentication to read the username and password for the Active Directory user that can be used
to perform AD lookups.

### Provisioning

No changes to the provisioning are applied other than the default one for the base image.

### Logs

No additional configuration is applied other than the default one for the base image.

### Metrics

Metrics are collected from Grafana via [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/).

## Build, test and release

The build process follows the standard procedure for
[building Calvinverse images](https://www.calvinverse.net/documentation/how-to-build).

## Deploy

* Download the new image to one of your Hyper-V hosts.
* Create a directory for the image and copy the image VHDX file there.
* Create a VM that points to the image VHDX file with the following settings
  * Generation: 2
  * RAM: at least 1024 Mb
  * Hard disk: Use existing. Copy the path to the VHDX file
  * Attach the VM to a suitable network
* Update the VM settings:
  * Enable secure boot. Use the Microsoft UEFI Certificate Authority
  * Attach a DVD image that points to an ISO file containing the settings for the environment. These
    are normally found in the output of the [Calvinverse.Infrastructure](https://github.com/Calvinverse/calvinverse.infrastructure)
    repository. Pick the correct ISO for the task, in this case the `Linux Consul Client` image
  * Disable checkpoints
  * Set the VM to always start
  * Set the VM to shut down on stop
* Start the VM, it should automatically connect to the correct environment once it has provisioned
* Remove the old VM
  * SSH into the host
  * Issue the `consul leave` command
  * Shut the machine down with the `sudo shutdown now` command
  * Once the machine has stopped, delete it
