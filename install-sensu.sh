#!/bin/bash
wget -q http://repos.sensuapp.org/apt/pubkey.gpg -O- | apt-key add -
echo "deb http://repos.sensuapp.org/apt sensu main" > /etc/apt/sources.list.d/sensu.list

apt-get update && apt-get install -y git-core rabbitmq-server redis-server supervisor sensu uchiwa
echo "sensu hold" | dpkg --set-selections

# rabbitmq-plugins enable rabbitmq_management
# chown -R rabbitmq:rabbitmq /etc/rabbitmq/
# service rabbitmq-server start

mkdir -p /etc/rabbitmq/ssl
cp /tmp/ssl_certs/sensu_ca/cacert.pem /tmp/ssl_certs/server/cert.pem /tmp/ssl_certs/server/key.pem /etc/rabbitmq/ssl

cat << EOF > /etc/rabbitmq/rabbitmq.config
[
  {rabbit, [
    {ssl_listeners, [5671]},
      {ssl_options, [{cacertfile,"/etc/rabbitmq/ssl/cacert.pem"},
      {certfile,"/etc/rabbitmq/ssl/cert.pem"},
      {keyfile,"/etc/rabbitmq/ssl/key.pem"},
      {verify,verify_peer},
      {fail_if_no_peer_cert,true}]}
  ]}
].
EOF

service rabbitmq-server start

rabbitmqctl add_vhost /sensu
rabbitmqctl add_user sensu pass
rabbitmqctl set_permissions -p /sensu sensu ".*" ".*" ".*"

echo "EMBEDDED_RUBY=true" > /etc/default/sensu & ln -s /opt/sensu/embedded/bin/ruby /usr/bin/ruby
/opt/sensu/embedded/bin/gem install redphone --no-rdoc --no-ri
/opt/sensu/embedded/bin/gem install mail --no-rdoc --no-ri --version 2.5.4

rm -rf /etc/sensu/plugins
git clone https://github.com/sensu/sensu-community-plugins.git /tmp/sensu_plugins

cp -Rpf /tmp/sensu_plugins/plugins /etc/sensu/
find /etc/sensu/plugins/ -name *.rb -exec chmod +x {} \;
