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
      #{admin} git clone --recursive git@github.com:#{repository_id}.git
    GIT
    puts 'Cloning repository ...'
    status, stdout, stderr = systemu(cmd)
    Logger.log("Cloning base repository git@github.com:#{config[:github_login]}/#{repository_id}.git - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
  end


  def Git.delete_local_testing_branch
    config = ConfigFile.read
    admin = Git.admin
    repository_path = Repository.get_path
    cmd = <<-GIT
      cd #{repository_path} &&
      #{admin} git reset --hard &&
      #{admin} git remote rm #{config[:remote_name]} &&
      #{admin} git clean -df &&
      #{admin} git checkout origin master &&
      #{admin} git branch -D #{config[:testing_branch_name]}
    GIT
    status, stdout, stderr = systemu(cmd)
    Logger.log("Deleting local testing branch #{config[:testing_branch_name]} - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
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
    Logger.log("Deleting remote testing branch #{config[:testing_branch_name]} - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
  end

  def Git.create_local_testing_branch(pull_request)
    config = ConfigFile.read
    admin = Git.admin
    repository_path = Repository.get_path
    if pull_request[:head_fork] = true 
    cmd = <<-GIT
      cd #{repository_path} &&
      #{admin} git reset --hard &&
      #{admin} git clean -df &&
      #{admin} git remote add #{config[:remote_name]} #{pull_request[:head_url]} &&
      #{admin} git remote update &&
      #{admin} git pull origin #{pull_request[:base_branch]}&&
      #{admin} git checkout -b #{config[:testing_branch_name]} &&
      #{admin} git pull #{config[:remote_name]} #{pull_request[:head_branch]}
    GIT
  else
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
  end
    status, stdout, stderr = systemu(cmd)
    Logger.log("Creating local testing branch #{config[:testing_branch_name]} - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
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
