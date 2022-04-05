# About

This terraform module will provision a zeppelin vm in openstack.

The zeppelin server provisioned has the following characteristics:
- It provisions executors in a kubernetes cluster
- It uses s3
- It uses an hive metastore
- It uses spark 3 in scala
- It saves its notebooks in s3
- It expects to communicate with a group of kubernetes workers to access the hive metastore and it expects its client traffic to originate from the kubernetes cluster's workers (probably via an ingress solution)
- It uses keycloak for user authentication

# Motivation

We experimented orchestrating zeppelin directly in kubernetes using its built-in support for kubernetes, but we felt it was too bleeding edge at the current time.

It didn't work well out of the box and while we were approaching a working solution tweaking it, we came to the realisation that the end result would not be easy to maintain in the future.

So instead, we made the tradeof of having a saner zeppelin deployment that runs outside of kubernetes while having the executor that it spawns run in kubernetes (which is what we care most about).

# Input Variables

- **name**: Name to give to the vm. Will be the hostname as well.
- **vcpus**: Number of vcpus to assign to the vm. Defaults to 2.
- **memory**: Amount of memory in MiB to assign to the vm. Defaults to 8192.
- **volume_id**: Id of the image volume to attach to the vm. A recent version of ubuntu is recommended as this is what this module has been validated against.
- **network_id**: Id (ie, uuid) of the libvirt network to connect the vm to if you wish to connect the vm to a libvirt network.
- **ip**: Ip of the vm if you opt to connect it to a libvirt network. Note that this isn't an optional parameter. Dhcp cannot be used.
- **mac**: Mac address of the vm if you opt to connect it to a libvirt network. If none is passed, a random one will be generated.
- **macvtap_interfaces**: List of macvtap interfaces to connect the vm to if you opt for macvtap interfaces instead of a libvirt network. Each entry in the list is a map with the following keys:
  - **interface**: Host network interface that you plan to connect your macvtap interface with.
  - **prefix_length**: Length of the network prefix for the network the interface will be connected to. For a **192.168.1.0/24** for example, this would be 24.
  - **ip**: Ip associated with the macvtap interface. 
  - **mac**: Mac address associated with the macvtap interface
  - **gateway**: Ip of the network's gateway for the network the interface will be connected to.
  - **dns_servers**: Dns servers for the network the interface will be connected to. If there aren't dns servers setup for the network your vm will connect to, the ip of external dns servers accessible accessible from the network will work as well.
- **cloud_init_volume_pool**: Name of the volume pool that will contain the cloud-init volume of the vm.
- **cloud_init_volume_name**: Name of the cloud-init volume that will be generated by the module for your vm. If left empty, it will default to **<name>-cloud-init.iso**.
- **ssh_admin_user**: Username of the default sudo user in the image. Defaults to **ubuntu**.
- **admin_user_password**: Optional password for the default sudo user of the image. Note that this will not enable ssh password connections, but it will allow you to log into the vm from the host using the **virsh console** command.
- **ssh_admin_public_key**: Public part of the ssh key the admin will be able to login as
- **nameserver_ips**: Ips of nameservers that will be added to the list of nameservers the zeppelin server refers to to resolve domain names.
- **zeppelin_mirror**: Mirror to download zeppelin from. Defaults to the university of Waterloo.
- **k8_executor_image**: Image to use to launch executor containers in kubernetes. Defaults to **chusj/spark:7508c20ef44952f1ee2af91a26822b6efc10998f**
- **k8_api_endpoint**: Kubernetes api endpoint that zeppelin will use to provision executors on kubernetes.
- **k8_ca_certificate**: Kubernetes ca certificate that zeppelin will use to authentify the api server.
- **k8_client_certificate**: Kubernetes client certificate that zeppelin will use to authentify itself to the api server.
- **k8_client_private_key**: Kubernetes private key that zeppelin will use to authentify itself to the api server.
- **s3_access**: S3 access key that zeppelin will use to identify itself to the s3 provider.
- **s3_secret**: S3 access key that zeppelin will use to authentify itself to the S3 provider.
- **s3_url**: url of the S3 provider that zeppelin will use.
- **hive_metastore_port**: Port that zeppelin will talk to on the k8 workers to access the hive metastore. Note that you still need to specify this port in the url argument below. This argument is simply to insure that the security groups on the k8 workers grant access to zeppelin on the given port.
- **hive_metastore_url**: Url of the hive metastore that zeppelin will use.
- **spark_sql_warehouse_dir**: S3 path of the spark sql warehouse
- **notebook_s3_bucket**: S3 bucket under which zeppelin will store its notebooks
- **keycloak_url**: Url of Keycloak server
- **keycloak_realm**: Name of Keycloak realm
- **keycloak_client_id**: Id of Keycloak client
- **keycloak_client_secret**: Secret of Keycloak client
- **zeppelin_url**: Url used to access zeppelin

# Usage Example

TODO