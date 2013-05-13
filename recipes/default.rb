#
# Cookbook Name:: mms-agent
# Recipe:: default
#
# Copyright 2011, Treasure Data, Inc.
#
# All rights reserved - Do Not Redistribute
#
include_recipe 'python'

#require 'fileutils'

# munin-node for hardware info
if node[:mms_agent][:monitor_hardware]
  package 'munin-node'
  service "munin-node" do
    action [:enable, :start]
    supports :status => true
  end
end

# download
file_name = node[:mms_agent][:source].split('/').last
cache_path = "#{Chef::Config[:file_cache_path]}/#{file_name}"
remote_file cache_path do
  source node[:mms_agent][:source]
end

if file_name.end_with? '.zip'
  package 'unzip'
  execute 'unzip 10gen-mms-agent' do
    cwd Chef::Config[:file_cache_path]
    command "unzip -o -d /usr/local/share/ #{cache_path}"
    creates '/usr/local/share/mms-agent'
  end
else
  execute "extract archive" do
    command "tar xzf #{cache_path} -C /usr/local/share/"
    creates "/usr/local/share/mms-agent"
  end
end

# install pymongo
python_pip 'pymongo' do
  action :install
end

#If login/mdp are not provided, we consider that agent has been downloaded from secret location
if !node[:mms_agent][:api_key].nil? and !node[:mms_agent][:secret_key].nil?
  ruby_block 'modify settings.py' do
    block do
      orig_s = ''
      open('/usr/local/share/mms-agent/settings.py') { |f|
        orig_s = f.read
      }
      s = orig_s
      s = s.gsub(/mms\.10gen\.com/, 'mms.10gen.com')
      s = s.gsub(/@API_KEY@/, node[:mms_agent][:api_key])
      s = s.gsub(/@SECRET_KEY@/, node[:mms_agent][:secret_key])
      if s != orig_s
        open('/usr/local/share/mms-agent/settings.py','w') { |f|
          f.puts(s)
        }
      end
    end
  end
end

directory "/var/log/mms" do
  owner node[:mms_agent][:user]
  group node[:mms_agent][:group]
  mode '0755'
end

case node[:mms_agent][:init_style]
when "runit"
  include_recipe 'runit'
  runit_service 'mms-agent' do
    template_name 'mms-agent'
    cookbook 'mongodb-mms-agent'
    options({
      :user => node[:mms_agent][:user],
      :group => node[:mms_agent][:group]
    })
  end
else
  template "/etc/init.d/mms-agent" do
    source 'initd.erb'
    mode '0744'
    variables(
      :user => node[:mms_agent][:user],
      :python_path => node[:python][:binary]
    )
  end
  service "mms-agent" do
    action [:enable,:start]
  end
end
