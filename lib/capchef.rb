require 'rubygems'
require 'erb'
require 'yaml'
require 'json'

module Capchef
  extend self

  # Default to /tmp but allow change in case it is noexec
  def tmpdir
    @tmpdir ||= '/tmp'
  end

  def tmpdir=(tmpdir)
    @tmpdir = tmpdir
  end

  def path
    @path ||= '/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'
  end

  def path=(path)
    @path = path
  end

  def prepend_path(dir)
    @path = "#{dir}:#{path}"
  end

  def use_sudo=(val)
    @use_sudo = val
  end
  
  def use_sudo?
    return true  if ENV['CAPCHEF_SUDO'] == 'true'
    return false if ENV['CAPCHEF_SUDO'] == 'false'
    # Default to true if unset
    @use_sudo = true if @use_sudo.nil?
    return @use_sudo
  end

  def sudo_options
    @sudo_options ||= ''
  end

  def sudo_options=(val)
    @sudo_options = val
  end

  # Runs +command+ as root invoking the command with 'su -c' and handling the root password prompt.
  #
  #   surun cap, "/etc/init.d/apache reload"
  #   # Executes
  #   # su - -c '/etc/init.d/apache reload'
  #
  #   surun cap, 'my_install' do |channel, stream, output|
  #     channel.send_data("\n") if output && output =~ /to continue/
  #     channel.send_data("y\n") if output && output =~ /replace/
  #   end
  def surun(cap, command, options={}, &block)
    if use_sudo?
      if command.kind_of?(Array)
        my_surun_script(cap, 'surun', command, nil, options, &block)
      else
        sucmd = "#{cap.sudo} #{sudo_options} PATH=#{path} #{command}"
        cap.run(sucmd, options, &block)
      end
    else
      @root_password ||= cap.fetch(:root_password, Capistrano::CLI.password_prompt("root password: "))
      command = command.join(';') if command.kind_of?(Array)
      sucmd = "su -c 'cd; PATH=#{path}; #{command}'"
      cap.run(sucmd, options) do |channel, stream, output|
        puts "[#{channel[:host]}] #{output}" if output
        channel.send_data("#{@root_password}\n") if output && output =~ /^Password:/
        yield channel, stream, output if block_given?
      end
    end
  end

  def surun_script(cap, script, args=nil, options={}, &block)
    raise "No such file: #{script}" unless File.exist?(script)
    my_surun_script(cap, script, nil, args, options, &block)
  end

  def nodes_config
    # The config file might want access to information that is contained within it (all_nodes for instance).
    # If so, make sure the 2nd pass doesn't try to acquire the same info or we will have an endless loop
    @config_pass ||= 0
    @nodes_config ||= begin
      nodes_file = ENV['NODES_FILE'] || 'nodes.yml'
      raise "No file #{nodes_file}" unless File.exist?(nodes_file)
      @config_pass += 1
      config = YAML.load(ERB.new(File.read(nodes_file), nil, '-').result(binding))
      @config_pass -= 1
      config
    end
  end

  def all_nodes(filter=nil)
    return [] if @config_pass && @config_pass > 1
    return nodes_config.keys.grep(Regexp.new(filter)) if filter
    return nodes_config.keys
  end

  private

  # Hack way to allow either a script or a list of commands
  def my_surun_script(cap, script, command_array, args, options, &block)
    basename = File.basename(script)
    script_dir = "#{tmpdir}/#{basename}.#$$"
    remote_script = "#{script_dir}/#{basename}"
    cap.run "mkdir #{script_dir}", options
    if command_array
      commands = command_array.join("\n")
      script_text = "#!/bin/sh\n#{commands}\n"
      cap.put script_text, remote_script, options
    else
      cap.upload script, remote_script, options
    end
    cap.run "chmod 0755 #{remote_script}", options
    cmd = remote_script
    cmd += ' ' + args if args
    surun cap, cmd, options, &block
  ensure
    cap.run "rm -rf #{script_dir}", options unless ENV['CAPCHEF_KEEP_TEMP']
  end
end
