#!/usr/bin/ruby -w

$app_name = ENV.fetch("APP_NAME") { |_|
  puts "APP_NAME not set."
  exit 1
}

$env = ENV.fetch("ENV") { |_|
  puts "ENV not set."
  exit 1
}

$instance = ENV.fetch("INSTANCE", "")

$git_branch = ENV.fetch("GIT_BRANCH", $env)

$git_repo = ENV.fetch("GIT_REPO", "firecloud-develop")

$dockerhub_tag = ENV.fetch("DOCKERHUB_TAG", $env)

$manifest = ENV.fetch("MANIFEST", "manifest.rb")

output_dir = ENV.fetch("OUTPUT_DIR") { |_|
  puts "OUTPUT_DIR not set."
  exit 1
}

$working_dir = ENV.fetch("DIR", output_dir)

# If set, files will be copied from this directory instead of from GitHub. Useful for testing new
# configuration changes.
$input_dir = ENV["INPUT_DIR"]
$input_dir = $input_dir ? File.absolute_path($input_dir) : nil

# If specified, the existing configuration directory will be silently overwritten upon successful
# completion.
$suppress_prompt = ARGV[0] == "-y"

# For catching errors
$failure_rendering = false
$failed_to_render_file_names = Array.new


require "base64"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

$vault_token = ENV["VAULT_TOKEN"]
if $vault_token.nil?
  begin
    $vault_token = File.read("#{ENV['HOME']}/.vault-token")
  rescue StandardError
    nil
  end
end
if $vault_token.nil?
  STDERR.puts "Could not find vault token. Tried VAULT_TOKEN environment variable and " +
              "#{ENV['HOME']}/.vault-token"
  exit 1
end
$vault_token = $vault_token.chomp

$github_api_url_root = "https://api.github.com/repos/broadinstitute/#{$git_repo}/contents"
$vault_url_root = "https://clotho.broadinstitute.org:8200/v1"
$github_token = nil

$default_config_path = "configs/#{$app_name}"

def copy_file_from_github(path, output_file_name)
  if output_file_name.nil?
    output_file_name = File.basename(path)
  end
  curl_cmd = [
    "curl",
    "-H", "Authorization: token #{$github_token}",
    "#{$github_api_url_root}/#{path}?ref=#{$git_branch}"
  ]
  Open3.popen3(*curl_cmd) { |stdin, stdout, stderr, wait_thread|
    response = JSON.load(stdout)
    # This GitHub endpoint seems to always return the content as a base-64-encoded string, but
    # assert that just to be safe.
    unless response["encoding"] == "base64"
      STDERR.puts "Expected content to be base64 encoded:"
      STDERR.puts JSON.pretty_generate(response)
      exit 1
    end
    content = response["content"]
    File.write(output_file_name, Base64.decode64(content))
  }
end

# path is full path from working directory
def copy_file_from_path(path, output_file_name = nil, silent = false)
  if output_file_name.nil?
    output_file_name = File.basename(path)
  end

  if $input_dir
    FileUtils.cp("#{$input_dir}/#{path}", "#{output_file_name}")
  else
    $github_token = ENV["GITHUB_TOKEN"]
    if $github_token.nil?
      begin
        $github_token = File.read("#{ENV['HOME']}/.github-token")
      rescue StandardError
        nil
      end
    end
    if $github_token.nil?
      STDERR.puts "Could not copy file. INPUT_DIR is not set. GITHUB_TOKEN is not set. Could not " +
                  "find token in #{ENV['HOME']}/.github-token"
      exit 1
    end
    $github_token = $github_token.chomp

    copy_file_from_github(path, output_file_name)
  end
  if not silent
    puts "#{path} > #{output_file_name}"
  end
end

def copy_file(file_name, output_file_name = nil, custom_path = nil)
  if custom_path
    path = "#{custom_path}/#{file_name}"
  else
    path = "#{$default_config_path}/#{file_name}"
  end
  copy_file_from_path(path, output_file_name)
end

def set_vault_token
  if $vault_token.nil?
    $vault_token = ENV["VAULT_TOKEN"]
  end
  if $vault_token.nil?
    begin
      $vault_token = File.read("#{ENV['HOME']}/.vault-token")
    rescue StandardError
      nil
    end
  end
  if $vault_token.nil?
    STDERR.puts "Could not find vault token. Tried VAULT_TOKEN environment variable and " +
                "#{ENV['HOME']}/.vault-token"
    exit 1
  end
  $vault_token = $vault_token.chomp
end

def read_secret_from_path(path, field = nil)
  if field.nil?
    field = "value"
  end

  # Not sure why Vault requires the -1 flag, but it does.
  curl_cmd = ["curl", "-1", "-H", "X-Vault-Token: #{$vault_token}", "#{$vault_url_root}/#{path}"]
  Open3.popen3(*curl_cmd) { |stdin, stdout, stderr, wait_thread|
    coutput = stdout.read
    if wait_thread.value.success?
      json = JSON.load(coutput)
      data = json["data"]
      if data.nil?
        STDERR.puts "Could not find secret at path: #{path}"
        STDERR.puts JSON.pretty_generate(json)
        exit 1
      end
      value = data[field]
      if value.nil?
        STDERR.puts "Could not find field '#{field}' in vault data:"
        STDERR.puts JSON.pretty_generate(data)
        exit 1
      end
      value
    else
      STDERR.puts "Curl command failed:"
      STDERR.puts stderr.read
      exit 1
    end
  }
end

def read_secret(file_name, field = nil)
  read_secret_from_path("secret/dsde/#{$env}/#{$app_name}/#{file_name}", field)
end

def copy_secret_from_path(path, field = nil, output_file_name = nil, silent = false)
  if output_file_name.nil?
    output_file_name = File.basename(path)
  end
  IO.write(output_file_name, read_secret_from_path(path, field))
  if not silent
    puts "#{path} > #{output_file_name}"
  end
end

def copy_secret(file_name, field = nil, output_file_name = nil)
  copy_secret_from_path("secret/dsde/firecloud/#{$env}/#{$app_name}/#{file_name}", field, output_file_name)
end

def render_from_path(path, output_file_name = nil)
  file_name = File.basename(path)
  if output_file_name.nil?
    base, ext, _ = file_name.split(".")
    if _.nil?
      output_file_name = "#{base}"
    else
      output_file_name = "#{base}.#{ext}"
    end
  end
  copy_file_from_path(path)
  docker_cmd = [
    "docker", "run", "--rm", "-w", "/w", "-v", "#{Dir.pwd}:/w",
    "-e", "VAULT_TOKEN=#{$vault_token}", "-e", "ENVIRONMENT=#{$env}", "-e", "DOCKERHUB_TAG=#{$dockerhub_tag}", "-e", "DIR=#{$working_dir}",
    "broadinstitute/dsde-toolbox:latest",
    "consul-template", "-config=/etc/consul-template/config/config.json",
    "-template=#{file_name}:#{output_file_name}",
    "-once"
  ]
  Open3.popen3(*docker_cmd) { |stdin, stdout, stderr, wait_thread|
    if wait_thread.value.success?
      puts "#{file_name} > #{output_file_name}"
      File.delete(file_name)
    else
      puts stderr.read
      $failure_rendering = true
      $failed_to_render_file_names.push(file_name)
    end
  }
end

def render(file_name, output_file_name = nil, custom_path = nil)
  if custom_path
    path = "#{custom_path}/#{file_name}"
  else
    path = "#{$default_config_path}/#{file_name}"
  end
  render_from_path(path, output_file_name)
end

def base64decode(input_file_name, output_file_name)
  File.write(output_file_name, Base64.decode64(File.read(input_file_name)))
  puts "#{input_file_name} > #{output_file_name}"
  File.delete(input_file_name)
end

puts "Creating configuration for\n  #{$app_name}/#{$env}\ninto\n  #{output_dir}\n..."

Dir.mktmpdir(nil, Dir.pwd) {|dir|
  Dir.chdir(dir) do
    puts "Grabbing manifest..."
    manifest_name = File.basename($manifest)

    if manifest_name == "manifest.rb"
      copy_file_from_path("configs/#{$app_name}/#{manifest_name}", nil, true)
    else
      copy_file_from_path("#{$manifest}", nil, true)
    end

    eval(File.read("#{manifest_name}"))
    File.delete("#{manifest_name}")
  end

  if File.exist?(output_dir)
    should_overwrite = false
    if $suppress_prompt
      should_overwrite = true
    else
      print "\n#{output_dir} exists.\nOverwrite with new config? (y/n): "
      STDOUT.flush
      answer = gets.chomp
      if answer == "y"
        should_overwrite = true
      end
    end
    if should_overwrite
      FileUtils.rm_rf(output_dir)
      FileUtils.cp_r("#{dir}/.", output_dir)
      puts "\n* New configuration written to #{output_dir}"
    else
      puts "New configuration discarded."
    end
  else
    FileUtils.cp_r("#{dir}/.", output_dir)
    puts "\n* New configuration written to #{output_dir}"
  end

  # if encountered a rendering failure, fail the whole script
  if $failure_rendering
    puts "ERROR REPORT! Configure failed for the following file(s)!"
    $failed_to_render_file_names.each { |x| puts x }
    exit 1
  end
}
