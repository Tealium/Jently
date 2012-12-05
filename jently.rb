require 'rubygems'
require './lib/git.rb'
require './lib/github.rb'
require './lib/jenkins.rb'
require './lib/helpers.rb'

def test_pull_request(pull_request_id)
  begin
    config = ConfigFile.read
    pull_request = Github.get_pull_request(pull_request_id)
    #Uncomment the line below if you want to trigger a build from a 
    #when a specific pull request comment is made on open pull requests.
    is_comment_valid = Github.get_pull_request_comment(pull_request_id)
    #Uncomment the line below and comment out the line above if you want to 
    #trigger a build when a pull request is created.
    #is_comment_valid = 'true'
    is_test_required = PullRequestsData.is_test_required(pull_request, is_comment_valid)
    PullRequestsData.update(pull_request)

    if is_test_required && is_comment_valid 
      if pull_request[:mergeable] == false
        Github.set_pull_request_status(pull_request_id, {:status => 'failure', :description => 'Unmergeable pull request.'})
      end

      if pull_request[:mergeable] == true
        Git.clone_repository if !Repository.exists_locally
        Git.delete_local_testing_branch
        Git.delete_remote_testing_branch
        Git.create_local_testing_branch(pull_request)
        #Git.push_local_testing_branch_to_remote

        Jenkins.wait_for_idle_executor

        thr = Thread.new do
          Github.set_pull_request_status(pull_request_id, {:status => 'pending', :description => 'Started work on pull request.'})
          job_id = Jenkins.start_job
          state = Jenkins.wait_on_job(job_id)
          Github.set_pull_request_status(pull_request_id, state, job_id)
        end

        timeout = thr.join(config[:jenkins_job_timeout_seconds]).nil?
        Github.set_pull_request_status(pull_request_id, {:status => 'error', :description => 'Job timed out.'}) if timeout
      end
    end
  rescue => e
    Github.set_pull_request_status(pull_request_id, {:status => 'error'})
    Logger.log('Error when testing pull request', e)
  end
end

while true
  begin
    config = ConfigFile.read
    open_pull_requests_ids = Github.get_open_pull_requests_ids
    PullRequestsData.remove_dead_pull_requests(open_pull_requests_ids)

    open_pull_requests_ids.each do |pull_request_id|
      test_pull_request(pull_request_id)
    end
  rescue => e
    Logger.log('Error in main loop', e)
  end
  sleep config[:github_polling_interval_seconds]
end
