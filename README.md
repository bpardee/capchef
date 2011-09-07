## capchef

* http://github.com/ClarityServices/capchef

### Introduction

capchef combines Capistrano with Chef to provide chef capabilities without
requiring a chef server.

### Install

    gem install capchef

### Usage

capchef assumes you have a directory structure that looks something like the following:

    chef-repo/
      cookbooks/
      roles/
      ...
    Gemfile
    Capfile
    nodes.yml

Your Gemfile might look something like the following:

    source :gemcutter
    gem 'capistrano'
    gem 'capchef'

Your Capfile might look something like the following:

    require 'capchef'
    require 'capchef/chef_recipes'
    require 'capchef/utility_recipes'

    role :node, *Capchef.all_nodes

    # Define the path to the chef-solo executable if it's not in /usr/bin or /usr/local/bin
    set :chef_solo_path, '/opt/ruby/bin'

Your nodes.yml might look something like the following:

    <% (1..10).each do |i| %>
    web<%= i %>:
      run_list:
        - role[web]
    <% end %>

    <% (1..5).each do |i| %>
    app<%= i %>:
      run_list:
        - role[app]
    <% end %>

    munin:
      munin:
        nodes: <%= (Capchef.all_nodes - ['munin']).join(',') %>
      run_list:
        - recipe[munin::server]
        - recipe[nginx::server]

Then you can install to your hosts with the following command:

    cap chef

## Author

Brad Pardee :: bradpardee@gmail.com

## License

Copyright 2011  Brad Pardee

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
