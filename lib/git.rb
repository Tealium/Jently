require 'rubygems'
require 'systemu'
require './lib/helpers.rb'

module Git
  def Git.admin
    admin = "sudo -u jenkins"
    return admin
  end

  def Git.clone_repository
    config = ConfigFile.read
    admin = Git.admin
    repository_id = Repository.get_id
    repository_dir = Repository.get_dir
    cmd = <<-GIT
      cd #{repository_dir} &&
      #{admin} git clone https://#{config[:github_login]}:#{config[:github_password]}@github.com/#{repository_id}.git
    GIT
    puts 'Cloning repository ...'
    status, stdout, stderr = systemu(cmd)
    Logger.log("Cloning repository - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
  end

  def Git.delete_local_testing_branch
    config = ConfigFile.read
    admin = Git.admin
    repository_path = Repository.get_path
    cmd = <<-GIT
      cd #{repository_path} &&
      #{admin} git reset --hard &&
      #{admin} git clean -df &&
      #{admin} git checkout master &&
      #{admin} git branch -D #{config[:testing_branch_name]}
    GIT
    status, stdout, stderr = systemu(cmd)
    Logger.log("Deleting local testing branch - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
  end

  def Git.delete_remote_testing_branch
    config = ConfigFile.read
    admin = Git.admin
    repository_path = Repository.get_path
    cmd = <<-GIT
      cd #{repository_path} &&
      #{admin} git reset --hard &&
      #{admin} git clean -df &&
      #{admin} git checkout master &&
      #{admin} git push origin :#{config[:testing_branch_name]}
    GIT
    status, stdout, stderr = systemu(cmd)
    Logger.log("Deleting remote testing branch - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
  end

  def Git.create_local_testing_branch(pull_request)
    config = ConfigFile.read
    admin = Git.admin
    repository_path = Repository.get_path
    cmd = <<-GIT
      cd #{repository_path} &&
      #{admin} git reset --hard &&
      #{admin} git clean -df &&
      #{admin} git fetch --all &&
      #{admin} git checkout #{pull_request[:head_branch]} &&
      #{admin} git reset --hard origin/#{pull_request[:head_branch]} &&
      #{admin} git clean -df &&
      #{admin} git checkout -b #{config[:testing_branch_name]} &&
      #{admin} git pull origin #{pull_request[:base_branch]}
    GIT
    status, stdout, stderr = systemu(cmd)
    Logger.log("Creating local testing branch - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
  end

  def Git.push_local_testing_branch_to_remote
    config = ConfigFile.read
    admin = Git.admin
    repository_path = Repository.get_path
    cmd = <<-GIT
      cd #{repository_path} &&
      #{admin} git reset --hard &&
      #{admin} git clean -df &&
      #{admin} git checkout #{config[:testing_branch_name]} &&
      #{admin} git push origin #{config[:testing_branch_name]}
    GIT
    status, stdout, stderr = systemu(cmd)
    Logger.log("Pushing local testing branch to remote - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
  end
end
