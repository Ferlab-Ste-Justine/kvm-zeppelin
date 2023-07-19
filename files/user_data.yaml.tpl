#cloud-config
%{ if admin_user_password != "" ~}
chpasswd:
  list: |
     ${ssh_admin_user}:${admin_user_password}
  expire: False
%{ endif ~}
preserve_hostname: false
hostname: ${node_name}
users:
  - default    
  - name: node-exporter
    system: True
    lock_passwd: True
  - name: ${ssh_admin_user}
    ssh_authorized_keys:
      - "${ssh_admin_public_key}"
write_files:
  #Chrony config
%{ if chrony.enabled ~}
  - path: /opt/chrony.conf
    owner: root:root
    permissions: "0444"
    content: |
%{ for server in chrony.servers ~}
      server ${join(" ", concat([server.url], server.options))}
%{ endfor ~}
%{ for pool in chrony.pools ~}
      pool ${join(" ", concat([pool.url], pool.options))}
%{ endfor ~}
      driftfile /var/lib/chrony/drift
      makestep ${chrony.makestep.threshold} ${chrony.makestep.limit}
      rtcsync
%{ endif ~}
  #Prometheus node exporter systemd configuration
  - path: /etc/systemd/system/node-exporter.service
    owner: root:root
    permissions: "0444"
    content: |
      [Unit]
      Description="Prometheus Node Exporter"
      Wants=network-online.target
      After=network-online.target
      StartLimitIntervalSec=0

      [Service]
      User=node-exporter
      Group=node-exporter
      Type=simple
      Restart=always
      RestartSec=1
      ExecStart=/usr/local/bin/node_exporter

      [Install]
      WantedBy=multi-user.target
  #DNS servers containing internal domain names
%{ if length(nameserver_ips) > 0 ~}
  - path: /opt/dns-servers
    owner: root:root
    permissions: "0444"
    content: |
%{ for ip in nameserver_ips ~}
      nameserver ${ip}
%{ endfor ~}
%{ endif ~}
  #Zeppelin configuration
  - path: /root/.aws/credentials
    owner: root:root
    permissions: "0400"
    content: |
      [default]
      aws_access_key_id = ${s3_access}
      aws_secret_access_key = ${s3_secret}
  - path: /opt/zeppelin-env.sh
    owner: root:root
    permissions: "0444"
    content: |
      export ZEPPELIN_ADDR=0.0.0.0
      export SPARK_HOME=/opt/spark
  - path: /opt/zeppelin-site.xml
    owner: root:root
    permissions: "0400"
    content: |
      <?xml version="1.0"?>
      <?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
      <configuration>
        <property>
          <name>zeppelin.notebook.s3.user</name>
          <value>zeppelin</value>
          <description>user name for s3 folder structure</description>
        </property>

        <property>
          <name>zeppelin.notebook.s3.bucket</name>
          <value>${notebook_s3_bucket}</value>
          <description>bucket name for notebook storage</description>
        </property>

        <property>
          <name>zeppelin.notebook.s3.endpoint</name>
          <value>${s3_url}</value>
          <description>endpoint for s3 bucket</description>
        </property>

        <property>
          <name>zeppelin.notebook.s3.timeout</name>
          <value>120000</value>
          <description>s3 bucket endpoint request timeout in msec.</description>
        </property>

        <property>
          <name>zeppelin.notebook.s3.signerOverride</name>
          <value>S3SignerType</value>
          <description>optional override to control which signature algorithm should be used to sign AWS requests</description>
        </property>

        <property>
          <name>zeppelin.notebook.s3.pathStyleAccess</name>
          <value>true</value>
          <description>Path style access for S3 bucket</description>
        </property>	

        <property>
          <name>zeppelin.notebook.storage</name>
          <value>org.apache.zeppelin.notebook.repo.S3NotebookRepo</value>
          <description>notebook persistence layer implementation</description>
        </property>
      </configuration>
  #Spark configuration
  - path: /opt/spark-defaults.conf
    owner: root:root
    permissions: "0400"
    content: |
      spark.master 	                                k8s://${k8_api_endpoint}
      spark.kubernetes.container.image 	            ${k8_executor_image}
      spark.kubernetes.authenticate.caCertFile      /opt/k8/ca.crt
      spark.kubernetes.authenticate.clientCertFile  /opt/k8/k8.crt
      spark.kubernetes.authenticate.clientKeyFile   /opt/k8/k8.key
      spark.jars.repositories                       https://s01.oss.sonatype.org/content/repositories/snapshots,https://s01.oss.sonatype.org/content/repositories/releases
      spark.jars.packages                           org.apache.hadoop:hadoop-aws:3.3.1,com.amazonaws:aws-java-sdk-bundle:1.11.901,io.delta:delta-core_2.12:1.0.0,io.projectglow:glow-spark3_2.12:1.2.1,bio.ferlab:datalake-spark3_2.12:1.1.0
      spark.jars.excludes                           org.apache.hadoop:hadoop-client
      SPARK_HOME                                    /opt/spark
      spark.hadoop.fs.s3a.impl                      org.apache.hadoop.fs.s3a.S3AFileSystem
      spark.hadoop.fs.s3a.fast.upload               true
      spark.hadoop.fs.s3a.connection.ssl.enabled    false
      spark.hadoop.fs.s3a.path.style.access         true
      spark.sql.warehouse.dir                       s3a://${spark_sql_warehouse_dir}
      spark.hadoop.fs.s3a.access.key                ${s3_access}
      spark.hadoop.fs.s3a.secret.key                ${s3_secret}
      spark.hadoop.fs.s3a.endpoint                  https://${s3_url}
      spark.hadoop.hive.metastore.uris              thrift://${hive_metastore_url}
      spark.sql.catalogImplementation               hive
      spark.sql.extensions                          io.delta.sql.DeltaSparkSessionExtension
      spark.sql.catalog.spark_catalog               org.apache.spark.sql.delta.catalog.DeltaCatalog
  #Shiro configuration
  - path: /opt/shiro.ini
    owner: root:root
    permissions: "0400"
    content: |
      [main]
      oidcConfig = org.pac4j.oidc.config.OidcConfiguration
      oidcConfig.withState = false
      oidcConfig.discoveryURI = ${keycloak_discovery_url}
      oidcConfig.clientId = ${keycloak_client_id}
      oidcConfig.secret = ${keycloak_client_secret}
      oidcConfig.scope = openid profile email roles
      oidcConfig.clientAuthenticationMethodAsString = client_secret_basic
      oidcConfig.disablePkce = true
%{ if keycloak_max_clock_skew > 0 ~}
      oidcConfig.maxClockSkew = ${keycloak_max_clock_skew}
%{ endif ~}

      authorizationGenerator = bio.ferlab.pac4j.authorization.generator.KeycloakRolesAuthorizationGenerator
      authorizationGenerator.clientId = zeppelin

      ajaxRequestResolver = org.pac4j.core.http.ajax.DefaultAjaxRequestResolver
      ajaxRequestResolver.addRedirectionUrlAsHeader = true

      oidcClient = org.pac4j.oidc.client.OidcClient
      oidcClient.configuration = $oidcConfig
      oidcClient.ajaxRequestResolver = $ajaxRequestResolver
      oidcClient.callbackUrl = ${zeppelin_url}/api/callback/
      oidcClient.ajaxRequestResolver = $ajaxRequestResolver
      oidcClient.authorizationGenerators = $authorizationGenerator

      clients = org.pac4j.core.client.Clients
      clients.clients = $oidcClient

      pac4jRealm = io.buji.pac4j.realm.Pac4jRealm
      pac4jRealm.principalNameAttribute = preferred_username
      pac4jSubjectFactory = io.buji.pac4j.subject.Pac4jSubjectFactory

      securityManager.subjectFactory = $pac4jSubjectFactory

      roleAuthorizer = org.pac4j.core.authorization.authorizer.RequireAnyRoleAuthorizer
      roleAuthorizer.elements = clin_administrator,clin_bioinformatician

      config = org.pac4j.core.config.Config
      config.clients = $clients
      config.authorizers = role:$roleAuthorizer

      oidcSecurityFilter = io.buji.pac4j.filter.SecurityFilter
      oidcSecurityFilter.config = $config
      oidcSecurityFilter.clients = oidcClient
      oidcSecurityFilter.authorizers = +role

      customCallbackLogic = bio.ferlab.pac4j.ForceDefaultURLCallbackLogic

      callbackFilter = io.buji.pac4j.filter.CallbackFilter
      callbackFilter.defaultUrl = ${zeppelin_url}
      callbackFilter.config = $config
      callbackFilter.callbackLogic = $customCallbackLogic

      cookie = org.apache.shiro.web.servlet.SimpleCookie
      cookie.name = JSESSIONID
      cookie.httpOnly = true
      cookie.secure = true

      sessionManager = org.apache.shiro.web.session.mgt.DefaultWebSessionManager
      sessionManager.sessionIdCookie = $cookie

      securityManager.sessionManager = $sessionManager
      securityManager.sessionManager.globalSessionTimeout = 86400000

      shiro.loginUrl = /api/login

      [urls]
      /api/version = anon
      /api/interpreter/setting/restart/** = oidcSecurityFilter
      /api/callback = callbackFilter
      /api/cluster/** = oidcSecurityFilter
      /api/notebook/**/permissions = oidcSecurityFilter
      /api/interpreter/** = oidcSecurityFilter, roles[clin_administrator]
      /api/configurations/** = oidcSecurityFilter, roles[clin_administrator]
      /api/credential/** = oidcSecurityFilter, roles[clin_administrator]
      /** = oidcSecurityFilter
  #Kubernetes Certificates
  - path: /opt/k8/ca.crt
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, k8_ca_certificate)}
  - path: /opt/k8/k8.crt
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, k8_client_certificate)}
  - path: /opt/k8/k8.key
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, k8_client_private_key)}
  #Additional Certificates
%{ for idx, cert in additional_certificates ~}
  - path: /opt/additional-cas/ca${idx}.crt
    owner: root:root
    permissions: "0444"
    content: |
      ${indent(6, cert)}
%{ endfor ~}
  - path: /opt/setup_additional_cas.sh
    owner: root:root
    permissions: "0444"
    content: |
      #!/bin/bash

      if [ -d "/opt/additional-cas" ] 
      then
        i=0
        for CA_FILE in /opt/additional-cas/ca*.crt; do
          cp $CA_FILE /usr/local/share/ca-certificates/;
          update-ca-certificates;

          openssl x509 -in $CA_FILE -inform pem -out "$${CA_FILE%.crt}.der" -outform der
          keytool -noprompt -importcert -trustcacerts -cacerts -alias "cqgc$${i}" -storepass changeit -file "$${CA_FILE%.crt}.der"
          let "i+=1"
        done
      fi
  #Zeppelin systemd configuration
  - path: /etc/systemd/system/zeppelin.service
    owner: root:root
    permissions: "0444"
    content: |
      [Unit]
      Description=Apache Zeppelin daemon
      After=syslog.target network.target

      [Service]
      Type=oneshot
      ExecStart=/opt/zeppelin/bin/zeppelin-daemon.sh start
      ExecStop=/opt/zeppelin/bin/zeppelin-daemon.sh stop
      RemainAfterExit=yes

      [Install]
      WantedBy=multi-user.target
packages:
  - curl
  #DNS Dependency
  - resolvconf
  #Zeppelin/Spark Dependency
  - openjdk-11-jdk
%{ if chrony.enabled ~}
  - chrony
%{ endif ~}
runcmd:
  #Finalize Chrony Setup
%{ if chrony.enabled ~}
  - cp /opt/chrony.conf /etc/chrony/chrony.conf
  - systemctl restart chrony.service 
%{ endif ~}
  #Add DNS Servers
%{ if length(nameserver_ips) > 0 ~}
  - systemctl start resolvconf.service
  - systemctl enable resolvconf.service
  - cat /opt/dns-servers >> /etc/resolvconf/resolv.conf.d/tail
  - systemctl restart resolvconf.service
  - resolvconf -u
%{ endif ~}
  #Add additional CAs
  - chmod +x /opt/setup_additional_cas.sh
  - /opt/setup_additional_cas.sh
  #Install Spark
  - cd /opt
  - wget https://github.com/Ferlab-Ste-Justine/spark-images/releases/download/v3.1.2/spark-3.1.2-bin-hadoop-3.3.1.tgz
  - tar xzf spark-3.1.2-bin-hadoop-3.3.1.tgz
  - mv spark-3.1.2-bin-hadoop-3.3.1 spark
  - rm spark-3.1.2-bin-hadoop-3.3.1.tgz
  - cp /opt/spark-defaults.conf /opt/spark/conf/spark-defaults.conf
  #Install Zeppelin
  - cd /opt
  - wget ${zeppelin_mirror}/apache/zeppelin/zeppelin-0.10.0/zeppelin-0.10.0-bin-netinst.tgz
  - tar xvzf zeppelin-0.10.0-bin-netinst.tgz
  - mv zeppelin-0.10.0-bin-netinst zeppelin
  - rm zeppelin-0.10.0-bin-netinst.tgz
  - wget https://github.com/Ferlab-Ste-Justine/zeppelin-oidc/releases/download/v0.1.0/zeppelin-oidc-jar-with-dependencies.jar
  - rm -rf /opt/zeppelin/lib/*
  - mv zeppelin-oidc-jar-with-dependencies.jar /opt/zeppelin/lib/
  - cp /opt/zeppelin-env.sh /opt/zeppelin/conf/zeppelin-env.sh
  - cp /opt/zeppelin-site.xml /opt/zeppelin/conf/zeppelin-site.xml
  - cp /opt/shiro.ini /opt/zeppelin/conf/shiro.ini
  - systemctl enable zeppelin
  - systemctl start zeppelin
  #Install prometheus node exporter as a binary managed as a systemd service
  - wget -O /opt/node_exporter.tar.gz https://github.com/prometheus/node_exporter/releases/download/v1.3.0/node_exporter-1.3.0.linux-amd64.tar.gz
  - mkdir -p /opt/node_exporter
  - tar zxvf /opt/node_exporter.tar.gz -C /opt/node_exporter
  - cp /opt/node_exporter/node_exporter-1.3.0.linux-amd64/node_exporter /usr/local/bin/node_exporter
  - chown node-exporter:node-exporter /usr/local/bin/node_exporter
  - rm -r /opt/node_exporter && rm /opt/node_exporter.tar.gz
  - systemctl enable node-exporter
  - systemctl start node-exporter
