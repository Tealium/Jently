require 'rubygems'
require './lib/git.rb'
require './lib/github.rb'
require './lib/jenkins.rb'
require './lib/helpers.rb'

def test_pull_request(pull_request_id)
  begin
    config = ConfigFile.read
    pull_request = Github.get_pull_request(pull_request_id)
    is_comment_valid, jenkins_job_name = Github.get_pull_request_comment(pull_request_id)
    is_test_required = PullRequestsData.is_test_required(pull_request, is_comment_valid)
    PullRequestsData.update(pull_request)

    if is_test_required && is_comment_valid 
      if pull_request[:mergeable] == false
        Github.set_pull_request_status(pull_request_id, {:status => 'failure', :description => 'Jenkins cannot test because the pull request is unmergeable.'}, jenkins_job_name)
      end

      if pull_request[:mergeable] == true
        thr = Thread.new do
          Github.set_pull_request_status(pull_request_id, {:status => 'pending', :description => 'Jenkins has started to work on your pull request.'}, jenkins_job_name)
          job_id = Jenkins.start_job(jenkins_job_name, pull_request_id)
          state = Jenkins.wait_on_job(job_id, jenkins_job_name)
          Github.set_pull_request_status(pull_request_id, state, job_id, jenkins_job_name)
        end

        Jenkins.wait_for_idle_executor

        timeout = thr.join(config[:jenkins_job_timeout_seconds]).nil?
        Github.set_pull_request_status(pull_request_id, {:status => 'failure', :description => 'Jenkins job has timed out.'}, jenkins_job_name) if timeout
        pull_request = Github.get_pull_request(pull_request_id)
        PullRequestsData.update(pull_request)
      end
    end
  rescue => e
   Github.set_pull_request_status(pull_request_id, {:status => 'error'}, jenkins_job_name) 
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
