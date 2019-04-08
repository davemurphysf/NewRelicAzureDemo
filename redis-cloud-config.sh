#cloud-config
groups:
  - ubuntu: [root,sys]
  - cloud-users
users:
  - default
  - name: app
    sudo: ALL=(ALL) NOPASSWD:ALL
write_files:
  - content: |
      license_key: ${nr_key}
      display_name: ${hostname}-redis
    path: /etc/newrelic-infra.yml
  - content: |
      deb [arch=amd64] https://download.newrelic.com/infrastructure_agent/linux/apt bionic main
    path: /etc/apt/sources.list.d/newrelic-infra.list
  - encoding: b64
    content: ${redis_config}
    path: /etc/redis-config.yml
package_update: true
package_upgrade: true
# runcmd:
#   - curl https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | sudo apt-key add -
#   - apt update && sudo apt install redis newrelic-infra nri-redis -y
#   - cp /etc/redis-config.yml /etc/newrelic-infra/integrations.d/redis-config.yml
#   - sed -i 's/bind 127.0.0.1 ::1/bind 0.0.0.0 ::1/' /etc/redis/redis.conf
#   - sed -i 's/protected-mode yes/protected-mode no/' /etc/redis/redis.conf
