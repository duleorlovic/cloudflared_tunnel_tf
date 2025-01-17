# Create lxd container and install cloudflared tunnel using ansible

Based on
https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/deployment-guides/ansible/

Install terraform, lxd and ansible
```
# https://developer.hashicorp.com/terraform/install
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# https://documentation.ubuntu.com/lxd/en/latest/tutorial/first_steps/
sudo snap install lxd
lxd init --minimal

# https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html
```

On LXC machine create a folder
```
ssh lxd-mashine

mkdir lxc
cd lxc

# clone the repo
git clone git@github.com:duleorlovic/cloudflare_tunnel_tf.git
```

Note that you can not have tunels and container with same name, so the best is
to use EDIT-THIS-mydomain.com_cloudflare_tunnel_tf
```
mv cloudflare_tunnel_tf EDIT-THIS-mydomain.com_cloudflare_tunnel_tf
# for example mv cloudflare_tunnel_tf my-app.trk.in.rs_cloudflare_tunnel_tf
```

Create `terraform.tfvars`
```
# terraform.tfvars
# your domain on cloudflare, bare domain without subdomain for example: "my-domain.com"
cloudflare_zone           = "EDIT-THIS-mydomain.com"
# find zone id when you go websites and click on your domain and scroll down
cloudflare_zone_id        = "EDIT-THIS-zone-id"
# find account id in url eg https://dash.cloudflare.com/123-this-is-account-id
cloudflare_account_id     = "EDIT-THIS-account-id"
# cloudflare username email
cloudflare_email          = "EDIT-THIS-email@example.com"
# https://developers.cloudflare.com/fundamentals/api/get-started/create-token/ with Cloudflare Tunnel and DNS permissions.
# My Profile > Api Tokens > Create Token > Create Custom Token
# Name >
#  EDIT-THIS-computer-name
# Permissions >
#   Account: Cloudflare Tunnel: Edit
#   Zone: DNS: Edit
# you can filter limit specific resources if needed
# copy API token and paste here
cloudflare_token          = "EDIT-THIS-api-token"

# LXC container name can contain only alphanumeric and hyphens, example my-app
lxd_container_name        = "EDIT-THIS-container-name"

# Subdomain is used for dns and tunnel ingress hostname, should be single word
# since cloudflare does not support sub-sub domains (ie default cert is only
# *.zone and on dashboard you can see: This hostname is not covered by a
# certificate.) we actually use two hostnames, one for web and one for ssh
# access, so for subdomain "my-app" we generate also "my-app-ssh" subdomain
# my-app.EDIT-THIS-mydomain.com
# my-app-ssh.EDIT-THIS-mydomain.com
# it could be the same as lxd_container_name "my-app" but you can set to "www"
# or empty subdomain "" if you serve on root domain
subdomain                 = "EDIT-THIS-my-subdomain"

# Machine name is used for tunnel name and container description
lxd_machine_name          = "EDIT-THIS-computer-name"

# Ubuntu version https://cloud-images.ubuntu.com/releases/
ubuntu_version            = "22.04"

# Enable this is you are using docker inside lxc container
# sample error is: error during container init: error mounting "cgroup" to rootfs
# at "/sys/fs/cgroup": mount src=cgroup, dst=/sys/fs/cgroup, dstFd=/proc/thread-self/fd/8,
# flags=0xf: permission denied: unknown.
use_docker              = false

# Pub key file is generated with ssh-keygen -f EDIT-THIS-container-name.key -N ""
default_public_key_file           = "EDIT-THIS-container-name.key.pub"

# if present, it will be added to the host .ssh/authorized_keys
additional_public_key_file           = "some-id-key.pub"
```

Run terraform
```
terraform init

ssh-keygen -f EDIT-THIS-container-name.key -N ""

terraform plan
terraform apply -auto-approve
```

Delete remove machine
```
terraform destroy -auto-approve
```

## Test connection from remote machine

From machine you want to ssh you need to install `brew install cloudflared` tool
and configure ssh to use it
```
# .ssh/config
Host EDIT-THIS-my-subdomain-ssh.EDIT-THIS-mydomain.com
  ProxyCommand $(brew --prefix)/bin/cloudflared access ssh --hostname %h
```
In your project create deploy folder
```
mkdir deploy
cd deploy

cat > .gitignore << HERE_DOC
my-key
my-key.pub
HERE_DOC

# download keys `my-key` and `my-key.pub`
scp lxd-mashine:lxc/my-app_cloudflare_tunnel_tf/my-key*  .

ssh-add my-app-key
```

and connect with
```
ssh ubuntu@EDIT-THIS-my-subdomain-ssh.EDIT-THIS-mydomain.com
```

Create ansible files
```
# inventory
[default]
EDIT-THIS-my-subdomain-ssh.EDIT-THIS-mydomain.com ansible_user=ubuntu

# ansible.cfg
[defaults]
inventory = inventory
```
and test connection
```
ansible all -m ping
```

## Debug

Test connection from lxd host using output command
```
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu  -i 10.89.228.210, playbook.yml

# or this generic command
ssh ubuntu@"$(get_container_ip my-app)" cat .ssh/authorized_keys
```

Check variables
```
cat tf_ansible_vars_file.yml
```

Debug ansible provision
```
terraform output ansible_playbook_command
```

Debug cloudflare tunnel with
```
lxc shell my-app

cat /etc/cloudflared/*

service cloudflared start

systemctl status cloudflared
tail /var/log/cloudflared.log
# same as:
journalctl -u cloudflared.service

cloudflared tunnel info my-app
```

DNS records need some time to update (create is instant but update is not)
```
ping my-app.my-domain.com
```
if the ping works from other computs but not on your mac you can clear cache
```
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

## SSL on cloudflare and on service

By default, cloudflare tunnel is served under https (http is automatically
redirected to https).
Note that certificate covers *.my-domain.com so sub-sub domains are not covered.
(sub.my-domain.com is OK, but sub.sub.my-domain.com has invalid certificate).

You can use page rules for custom redirection.

# SSH

TODO: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/use-cases/ssh/
