#cloud-config
groups:
  - ubuntu: [root,sys]
  - cloud-users
users:
  - default
  - name: app
    sudo: ALL=(ALL) NOPASSWD:ALL
write_files:
  - encoding: b64
    content: ${pm2_config}
    path: /etc/pm2_config.json
  - content: |
      license_key: ${nr_key}
      display_name: ${hostname}-app
    path: /etc/newrelic-infra.yml
  - content: |
      deb [arch=amd64] https://download.newrelic.com/infrastructure_agent/linux/apt bionic main
    path: /etc/apt/sources.list.d/newrelic-infra.list
package_update: true
package_upgrade: true
runcmd:
  - touch /etc/profile.d/00-pm2.sh
  - echo 'export PM2_HOME=/app/aot/.pm2' | tee -a '/etc/profile.d/00-pm2.sh'
  - touch /etc/sudoers.d/00-pm2
  - echo 'Defaults env_keep += "PM2_HOME"' | EDITOR='tee -a' visudo -f /etc/sudoers.d/00-pm2