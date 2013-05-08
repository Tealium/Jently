require 'rubygems'
require 'octokit'
require './lib/helpers.rb'

module Github
  def Github.get_open_pull_requests_ids
    begin
      config = ConfigFile.read
      repository_id = Repository.get_id
      client = Octokit::Client.new(:login => config[:github_login], :password => config[:github_password])
      open_pull_requests = client.pull_requests(repository_id, 'open')
      open_pull_requests_ids = open_pull_requests.collect { |pull_request| pull_request.number }
    rescue => e
      Logger.log('Error when getting open pull requests ids', e)
      sleep 5
      retry
    end
  end

  def Github.get_pull_request(pull_request_id)
    begin
      config = ConfigFile.read
      repository_id = Repository.get_id
      client = Octokit::Client.new(:login => config[:github_login], :password => config[:github_password])
      pull_request = client.pull_request(repository_id, pull_request_id)
      statuses = client.statuses(repository_id, pull_request.head.sha)

      data = {}
      data[:id] = pull_request.number
      data[:merged] = pull_request.merged
      data[:mergeable] = pull_request.mergeable
      data[:head_branch] = pull_request.head.ref
      data[:head_sha] = pull_request.head.sha
      data[:head_url] = pull_request.head.repo.ssh_url
      data[:head_fork] = pull_request.head.repo.fork
      data[:last_checked] = Time.now.strftime("%Y-%m-%d %H:%M")
      data[:status] = statuses.empty? ? 'undefined' : statuses.first.state

      # Update base_sha separately. The pull_request call is
      # not guaranteed to return the last sha of the base branch.
      data[:base_branch] = pull_request.base.ref    
      data[:base_sha] = client.commits(repository_id, data[:base_branch]).first.sha
      data[:base_fork] = pull_request.base.repo.fork
      data
    rescue => e
      Logger.log('Error when getting pull request', e)
      sleep 5
      retry
    end
  end

  def Github.get_pull_request_comment(pull_request_id)
    begin
      is_comment_valid = false
      jenkins_job_name = ""
      config = ConfigFile.read
      repository_id = Repository.get_id
      client = Octokit::Client.new(:login => config[:github_login], :password => config[:github_password])
      pull_request_comments = client.issue_comments(repository_id, pull_request_id)

      #Go into the pull request and look at each comment.
      pull_request_comments.each do |pull_request_comment|

        #if there is already a valid comment/user found no need to check the rest.
        break if is_comment_valid == true

        #Check to see if the user who commented on the pull request is liseted in the /config/config.yaml file
       has_correct_user = false
       has_correct_comment = false
        config[:testers].each do |tester, values|
          #Check to see if the comment left by the user matches the set tester comment listed in the /config/config.yaml file
          has_correct_comment = has_correct_comment || pull_request_comment.body.downcase == values[:tester_comment].downcase

          values[:tester_username].each do |username|
            has_correct_user = has_correct_user || pull_request_comment.user.login == username
          end
          jenkins_job_name = values[:jenkins_job_name] if has_correct_user && has_correct_comment
          break if has_correct_comment == true && has_correct_user == true
        end

        #Check to see if the comment left was made after the last check.
       new_date = DateTime.parse(pull_request_comment.updated_at)
             has_correct_time = false
             has_correct_time = has_correct_time || new_date.strftime("%Y-%m-%d %H:%M") >= PullRequestsData.read[pull_request_id][:last_checked] unless PullRequestsData.read[pull_request_id].nil?

        #if all three conditions are met return true
        is_comment_valid = has_correct_user && has_correct_comment && has_correct_time
      end
        return is_comment_valid, jenkins_job_name
    rescue => e
      Logger.log('Error when getting pull request comments', e)
      sleep 5
      retry
    end
  end

  def Github.set_pull_request_status(pull_request_id, state, job_id=0, jenkins_job_name="")
    begin
      config = ConfigFile.read
      repository_id = Repository.get_id
      head_sha = PullRequestsData.read[pull_request_id][:head_sha]

      opts = {}
      opts[:target_url] = state[:url] if !state[:url].nil?
      opts[:description] = state[:description] if !state[:description].nil?

      client = Octokit::Client.new(:login => config[:github_login], :password => config[:github_password])
      client.create_status(repository_id, head_sha, state[:status], opts)
      Github.set_pull_request_comment(pull_request_id,state[:status], job_id, jenkins_job_name) if state[:status] !=  'pending'
    rescue => e
      Logger.log('Error when setting pull request status', e)
      sleep 5
      retry
    end
  end
  
  def Github.set_pull_request_comment(pull_request_id, state_status, job_id, jenkins_job_name)
    begin
      config = ConfigFile.read
      repository_id = Repository.get_id
      if state_status == 'falure' and job_id == 0
        comment = "Jenkins cannot test because the pull request has merge conflicts."
      else
        jenkins_status = Jenkins.get_job_state(job_id, jenkins_job_name)
        build_id = jenkins_status[:url].split('/').last
        comment = "Jenkins build has completed with a status of #{state_status}. [Build # #{build_id}](#{jenkins_status[:url]})" 
      end
      client = Octokit::Client.new(:login => config[:github_login], :password => config[:github_password])
      client.add_comment(repository_id, pull_request_id, comment)
    rescue => e
      Logger.log('Error when setting pull request comment', e)
      sleep 5
      retry
    end
  end
end
