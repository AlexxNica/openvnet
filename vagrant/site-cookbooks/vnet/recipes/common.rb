#
# Cookbook Name:: vnet_common
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

include_recipe "vnet::base"

# yum
include_recipe "yum-epel"

node[:vnet][:packages][:common].each do |pkg|
  package pkg
end

# ntp
node.default[:ntp][:servers] = node[:vnet][:ntp_servers]
include_recipe "ntp"

# ssh
file "/home/vagrant/.ssh/id_rsa" do
  owner "vagrant"
  group "vagrant"
  mode "0600"
  content ::File.open("/vagrant/vm/ssh/id_rsa").read
end

# timezone
file "/etc/localtime" do
  owner "root"
  group "root"
  content ::File.open("/usr/share/zoneinfo/Japan").read
  action :create
end

# build openvswitch rpm
if node[:vnet][:repositry_server]
  bash "build_openvswitch_rpm" do
    code <<-EOS
      yum install -y make git gcc gcc-c++ rpm-build redhat-rpm-config rpmdevtools yum-utils python-devel openssl-devel kernel-devel-$(uname -r) kernel-debug-devel-$(uname -r) createrepo
      REPO_BASE_DIR=/vagrant/repos #{node[:vnet][:source_path]}/deployment/packagebuild/build_packages_third_party.sh openvnet-openvswitch
    EOS

    not_if { File.exists?("/vagrant/repos/packages/rhel/6/third_party/current/") }
  end
end

# rbenv
include_recipe "rbenv::default"
include_recipe "rbenv::ruby_build"

node[:vnet][:ruby_versions].each do |version|
  rbenv_ruby version do
    global version == node[:vnet][:ruby_global]
  end
 
  rbenv_gem "bundler" do
    ruby_version version
  end
end

# openvnet

execute "make update-config" do
  cwd node[:vnet][:source_path]
end

execute "replace RUBY_PATH" do
  command "sudo sed -i-e 's,RUBY_PATH=.*,RUBY_PATH=/opt/rbenv/shims,' /etc/default/openvnet"
end

template "/etc/openvnet/common.conf" do
  source "vnet.common.conf.erb"
  owner "root"
  group "root"
  variables({
    registry_host: node[:vnet][:config][:common][:registry_host],
    registry_port: node[:vnet][:config][:common][:registry_port],
    db_host: node[:vnet][:config][:common][:db_host],
    db_port: node[:vnet][:config][:common][:db_port],
  })
end
