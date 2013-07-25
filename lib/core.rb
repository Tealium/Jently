module Core
  def Core.test_pull_request(pull_request_id, jenkins_job_name)
    begin
      config = ConfigFile.read
      pull_request = PullRequestsData.read[pull_request_id]
      

    if is_test_required
      if pull_request[:mergeable] == false
        Github.set_pull_request_status(pull_request_id, {:status => 'failure', :description => 'Unmergeable pull request.'}, jenkins_job_name)
      end

      if pull_request[:mergeable] == true
        #Git.setup_testing_branch(pull_request)

        thr = Thread.new do
          Github.set_pull_request_status(pull_request_id, {:status => 'pending', :description => 'Jankins has started work on pull request.'}, jenkins_job_name)
          job_id = Jenkins.start_job(jenkins_job_name, pull_request_id)
          state = Jenkins.wait_on_job(job_id, jenkins_job_name)
          Github.set_pull_request_status(pull_request_id, state, job_id, jenkins_job_name)
        end
        
        Jenkins.wait_for_idle_executor

        timeout = thr.join(config[:jenkins_job_timeout_seconds]).nil?
        Github.set_pull_request_status(pull_request_id, {:status => 'error', :description => 'Jenkins job timed out.'}) if timeout
      end
    end
    rescue => e
      Github.set_pull_request_status(pull_request_id, {:status => 'error', :description => 'An error has occurred.'})
      Logger.log('Error when testing pull request', e)
    end
  end

  def Core.poll_pull_requests_and_queue_next_job
    open_pull_requests_ids = Github.get_open_pull_requests_ids
    PullRequestsData.remove_dead_pull_requests(open_pull_requests_ids)

    open_pull_requests_ids.each do |pull_request_id|
      pull_request = Github.get_pull_request(pull_request_id)
     # PullRequestsData.update(pull_request)
    end

    is_comment_valid, jenkins_jpb_name = Github.get_pull_request_comment(pull_request_id)
    is_merged = pull_request[:merged]
    is_test_required = !is_merged && is_comment_valid
    test_pull_request(pull_request_id_to_test, jenkins_job_name) if is_test_required
  end
end
